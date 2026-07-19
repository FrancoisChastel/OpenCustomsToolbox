#!/usr/bin/env python3
"""customs-query-tester — a privacy-preserving MCP server for testing SQL
against the Open Customs Toolbox schema (or any PostgreSQL database).

The model can VERIFY that a generated query is valid and runs, without ever
seeing row data. Guarantees, enforced server-side on every call:

  1. Read-only session   — PGOPTIONS sets default_transaction_read_only=on,
                           so INSERT/UPDATE/DELETE/DDL fail in the server even
                           if they slip past the lexical guard.
  2. Statement allowlist — a comment/string-aware scanner accepts a single
                           SELECT or WITH statement only; multi-statements and
                           write keywords are rejected before touching the DB.
  3. Metadata-only output — responses carry column names/types (via psql \\gdesc,
                           which describes without executing), an aggregate
                           row count (SELECT count(*) FROM (<query>) __q), and
                           timing. Row values are never read into the response.
  4. Bounded execution   — statement_timeout (default 5s) caps every call.

Transport: MCP stdio (newline-delimited JSON-RPC 2.0). Zero dependencies —
pure Python stdlib; database access shells out to `psql`.

Configuration (environment, or flags in .mcp.json args):
  CUSTOMS_DB / --db          database name or full DSN   (default: customs_sandbox)
  CUSTOMS_SCHEMA / --schema  schema for search_path       (default: asycuda)
  CUSTOMS_TIMEOUT_MS         statement timeout in ms      (default: 5000)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
def _flag(name: str, default: str) -> str:
    argv = sys.argv[1:]
    if name in argv:
        i = argv.index(name)
        if i + 1 < len(argv):
            return argv[i + 1]
    return default


DB = _flag("--db", os.environ.get("CUSTOMS_DB", "customs_sandbox"))
SCHEMA = _flag("--schema", os.environ.get("CUSTOMS_SCHEMA", "asycuda"))
TIMEOUT_MS = int(os.environ.get("CUSTOMS_TIMEOUT_MS", "5000"))
PSQL_TIMEOUT_S = TIMEOUT_MS / 1000 + 10  # subprocess hard cap

SERVER_INFO = {"name": "customs-query-tester", "version": "1.0.0"}
PRIVACY_NOTE = (
    "privacy: read-only transaction, single-SELECT allowlist, "
    f"{TIMEOUT_MS}ms timeout; no row data was read into this response."
)


# --------------------------------------------------------------------------
# psql plumbing — every connection is read-only with a bounded timeout
# --------------------------------------------------------------------------
def _psql_env() -> dict:
    env = dict(os.environ)
    env["PGOPTIONS"] = (
        "-c default_transaction_read_only=on "
        f"-c statement_timeout={TIMEOUT_MS} "
        f"-c search_path={SCHEMA},public"
    )
    env.setdefault("PGCONNECT_TIMEOUT", "5")
    return env


def run_psql(stdin_script: str) -> tuple[int, str, str]:
    """Run a psql script (commands via stdin) against DB. Returns (rc, out, err)."""
    try:
        proc = subprocess.run(
            ["psql", "-X", "--quiet", "-v", "ON_ERROR_STOP=1", "-A", "-t", "-d", DB],
            input=stdin_script,
            capture_output=True,
            text=True,
            timeout=PSQL_TIMEOUT_S,
            env=_psql_env(),
        )
        return proc.returncode, proc.stdout, proc.stderr
    except FileNotFoundError:
        return 127, "", "psql not found on PATH — install a PostgreSQL client."
    except subprocess.TimeoutExpired:
        return 124, "", f"psql subprocess exceeded {PSQL_TIMEOUT_S:.0f}s and was killed."


# --------------------------------------------------------------------------
# Lexical guard — comment/string-aware; single SELECT/WITH statements only
# --------------------------------------------------------------------------
FORBIDDEN = re.compile(
    r"\b(insert|update|delete|truncate|drop|alter|create|grant|revoke|copy|"
    r"call|do|vacuum|reindex|cluster|listen|notify|lock|merge|import|"
    r"security\s+definer)\b",
    re.IGNORECASE,
)


def strip_literals(sql: str) -> str:
    """Remove comments, quoted strings and dollar-quoted blocks so keyword and
    semicolon checks can't be fooled by literal content."""
    out, i, n = [], 0, len(sql)
    while i < n:
        ch = sql[i]
        nxt = sql[i + 1] if i + 1 < n else ""
        if ch == "-" and nxt == "-":                      # -- line comment
            i = sql.find("\n", i)
            i = n if i == -1 else i
        elif ch == "/" and nxt == "*":                    # /* block comment */
            j = sql.find("*/", i + 2)
            i = n if j == -1 else j + 2
        elif ch == "'":                                   # 'string' ('' escape)
            i += 1
            while i < n:
                if sql[i] == "'" and (i + 1 >= n or sql[i + 1] != "'"):
                    break
                i += 2 if sql[i] == "'" else 1
            i += 1
            out.append("''")
        elif ch == '"':                                   # "identifier"
            j = sql.find('"', i + 1)
            i = n if j == -1 else j + 1
            out.append('""')
        elif ch == "$":                                   # $tag$ ... $tag$
            m = re.match(r"\$[A-Za-z0-9_]*\$", sql[i:])
            if m:
                tag = m.group(0)
                j = sql.find(tag, i + len(tag))
                i = n if j == -1 else j + len(tag)
                out.append("''")
            else:
                out.append(ch)
                i += 1
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def guard(sql: str) -> str | None:
    """Return a rejection reason, or None if the query is allowed."""
    cleaned = strip_literals(sql).strip()
    if not cleaned:
        return "empty query"
    body = cleaned.rstrip(";").strip()
    if ";" in body:
        return "multiple statements are not allowed — send exactly one SELECT"
    first = re.match(r"[A-Za-z]+", body)
    if not first or first.group(0).lower() not in ("select", "with", "table", "values"):
        return (
            f"only read queries are allowed (SELECT/WITH); got "
            f"'{first.group(0) if first else body[:20]}'"
        )
    hit = FORBIDDEN.search(body)
    if hit:
        return f"forbidden keyword for this read-only tester: {hit.group(0).upper()}"
    # SELECT ... INTO creates a table; read-only mode blocks it server-side too,
    # but reject it lexically for a clearer, faster error.
    if re.search(r"\binto\b", body, re.IGNORECASE):
        return "SELECT ... INTO creates a table — not allowed in this read-only tester"
    return None


def bare(sql: str) -> str:
    """The query without trailing semicolon/whitespace (for wrapping)."""
    return sql.strip().rstrip(";").strip()


# --------------------------------------------------------------------------
# Tools
# --------------------------------------------------------------------------
def tool_describe_schema(args: dict) -> tuple[str, bool]:
    table = (args.get("table") or "").strip()
    if table:
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", table):
            return "invalid table name", True
        rc, out, err = run_psql(
            "SELECT column_name || ' | ' || data_type || ' | ' || "
            "CASE WHEN is_nullable='YES' THEN 'null' ELSE 'not null' END "
            "FROM information_schema.columns "
            f"WHERE table_schema='{SCHEMA}' AND table_name='{table}' "
            "ORDER BY ordinal_position;"
        )
        if rc != 0:
            return f"error: {err.strip()}", True
        if not out.strip():
            return f"table '{table}' not found in schema '{SCHEMA}'", True
        return f"{SCHEMA}.{table} — column | type | nullability\n{out.strip()}", False
    rc, out, err = run_psql(
        "SELECT table_name FROM information_schema.tables "
        f"WHERE table_schema='{SCHEMA}' AND table_type='BASE TABLE' ORDER BY 1;"
    )
    if rc != 0:
        return f"error: {err.strip()}", True
    tables = out.strip().splitlines()
    return (
        f"schema '{SCHEMA}' — {len(tables)} tables:\n" + "\n".join(tables) +
        "\n\nCall describe_schema with {\"table\": \"<name>\"} for columns."
    ), False


def tool_validate_query(args: dict) -> tuple[str, bool]:
    sql = args.get("sql", "")
    reason = guard(sql)
    if reason:
        return f"REJECTED before reaching the database: {reason}", True
    rc, out, err = run_psql(f"EXPLAIN (COSTS FALSE) {bare(sql)};")
    if rc != 0:
        return f"INVALID — PostgreSQL says:\n{err.strip()}", True
    return f"VALID — the planner accepted the query. Plan:\n{out.strip()}\n\n{PRIVACY_NOTE}", False


def tool_test_query(args: dict) -> tuple[str, bool]:
    sql = args.get("sql", "")
    reason = guard(sql)
    if reason:
        return f"REJECTED before reaching the database: {reason}", True
    q = bare(sql)

    # 1. Result shape via \gdesc — server-side describe, no execution, no data.
    rc, out, err = run_psql(f"{q}\n\\gdesc\n")
    if rc != 0:
        return f"FAILED at describe:\n{err.strip()}", True
    columns = [ln for ln in out.strip().splitlines() if ln.strip()]

    # 2. Row count via an aggregate wrapper — one number leaves the database.
    t0 = time.monotonic()
    rc, out, err = run_psql(f"SELECT count(*) FROM (\n{q}\n) AS __privacy_wrapper;")
    duration = time.monotonic() - t0
    if rc != 0:
        return f"FAILED at execution:\n{err.strip()}", True
    row_count = out.strip()

    cols = "\n".join(f"  {c.replace('|', '  ')}" for c in columns) or "  (no columns?)"
    return (
        "OK — query executed successfully (read-only).\n"
        f"rows: {row_count}\n"
        f"columns (name  type):\n{cols}\n"
        f"duration: {duration:.2f}s\n"
        f"{PRIVACY_NOTE}"
    ), False


# --------------------------------------------------------------------------
# Compiler bridge — logical query -> genuine ASYCUDA World SQL
# --------------------------------------------------------------------------
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAPPING = os.environ.get("CUSTOMS_MAPPING", "asycuda-world")
OVERRIDES = os.environ.get("CUSTOMS_OVERRIDES", "")


def run_compiler(logical_sql: str) -> tuple[int, str, str]:
    cmd = [sys.executable, "-m", "compiler", "compile", "-", "--mapping", MAPPING]
    if OVERRIDES:
        cmd += ["--overrides", OVERRIDES]
    try:
        proc = subprocess.run(
            cmd, input=logical_sql, capture_output=True, text=True, timeout=30, cwd=REPO_ROOT
        )
        return proc.returncode, proc.stdout, proc.stderr
    except FileNotFoundError:
        return 127, "", "python interpreter not found"
    except subprocess.TimeoutExpired:
        return 124, "", "compiler timed out"


def tool_compile_query(args: dict) -> tuple[str, bool]:
    logical = args.get("sql", "")
    reason = guard(logical)  # only single SELECT/WITH logical queries may be compiled
    if reason:
        return f"REJECTED: {reason}", True
    rc, genuine, err = run_compiler(logical)
    if rc != 0:
        return f"COMPILE FAILED:\n{err.strip() or 'compiler error'}", True

    parts = ["Genuine ASYCUDA World SQL (compiled from the logical query):\n", genuine.strip()]
    if err.strip():  # compiler warnings, e.g. unfilled per-instance placeholders
        parts.append("\n" + err.strip())
    if args.get("test"):
        vtext, verr = tool_test_query({"sql": genuine})
        parts.append("\n--- test_query on the compiled SQL (read-only, metadata only) ---\n" + vtext)
        return "\n".join(parts), verr
    return "\n".join(parts), False


TOOLS = [
    {
        "name": "describe_schema",
        "description": (
            "List the tables of the customs schema, or the columns/types of one "
            "table. Structural metadata only — never row data."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "table": {
                    "type": "string",
                    "description": "Optional table name; omit to list all tables.",
                }
            },
        },
    },
    {
        "name": "validate_query",
        "description": (
            "Validate a SELECT against the database with EXPLAIN — syntax, table "
            "and column references — WITHOUT executing it. Returns the plan or "
            "the PostgreSQL error. Rejects anything that is not a single SELECT."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {"sql": {"type": "string", "description": "The SQL query."}},
            "required": ["sql"],
        },
    },
    {
        "name": "test_query",
        "description": (
            "Execute a SELECT in a read-only, time-limited transaction and return "
            "ONLY metadata: column names/types, aggregate row count, duration. "
            "Row values are never returned — safe against databases holding real "
            "(sensitive) customs data. Rejects anything that is not a single SELECT."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {"sql": {"type": "string", "description": "The SQL query."}},
            "required": ["sql"],
        },
    },
    {
        "name": "compile_query",
        "description": (
            "Compile a LOGICAL query (written against the toolbox's friendly names "
            "— declaration, declaration_item, tax_amount, hs_code…) into GENUINE "
            "ASYCUDA World SQL (SAD_General_Segment, SAD_Tax.AMT, TAR_HSC concat…) "
            "that runs on a real Sydonia database. Set test=true to also run the "
            "compiled SQL read-only and report metadata (never row data)."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "sql": {"type": "string", "description": "The logical SQL query."},
                "test": {
                    "type": "boolean",
                    "description": "Also execute the compiled SQL read-only and report metadata.",
                },
            },
            "required": ["sql"],
        },
    },
]

HANDLERS = {
    "describe_schema": tool_describe_schema,
    "validate_query": tool_validate_query,
    "test_query": tool_test_query,
    "compile_query": tool_compile_query,
}


# --------------------------------------------------------------------------
# MCP stdio loop (newline-delimited JSON-RPC 2.0)
# --------------------------------------------------------------------------
def reply(msg_id, result=None, error=None) -> None:
    msg = {"jsonrpc": "2.0", "id": msg_id}
    if error is not None:
        msg["error"] = error
    else:
        msg["result"] = result
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        method, msg_id = msg.get("method", ""), msg.get("id")
        if method == "initialize":
            reply(msg_id, {
                "protocolVersion": msg.get("params", {}).get("protocolVersion", "2024-11-05"),
                "capabilities": {"tools": {}},
                "serverInfo": SERVER_INFO,
                "instructions": (
                    "Privacy-preserving SQL tester for the Open Customs Toolbox "
                    "schema. test_query/validate_query return metadata only — "
                    "never row data. Target DB: " + DB
                ),
            })
        elif method == "notifications/initialized":
            pass
        elif method == "ping":
            reply(msg_id, {})
        elif method == "tools/list":
            reply(msg_id, {"tools": TOOLS})
        elif method == "tools/call":
            params = msg.get("params", {})
            handler = HANDLERS.get(params.get("name", ""))
            if handler is None:
                reply(msg_id, error={"code": -32602, "message": f"unknown tool {params.get('name')!r}"})
                continue
            try:
                text, is_error = handler(params.get("arguments") or {})
            except Exception as exc:  # never crash the server on a tool bug
                text, is_error = f"internal tool error: {exc}", True
            reply(msg_id, {"content": [{"type": "text", "text": text}], "isError": is_error})
        elif msg_id is not None:
            reply(msg_id, error={"code": -32601, "message": f"method not found: {method}"})


if __name__ == "__main__":
    main()

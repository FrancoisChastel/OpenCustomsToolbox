# customs-query-tester — a privacy-preserving MCP server for SQL testing

A tiny [Model Context Protocol](https://modelcontextprotocol.io) server that
lets an AI assistant **prove a SQL query works** against a PostgreSQL database
**without ever seeing the data in it**.

## Why it exists

When Claude generates a query against the customs schema, "looks right" is not
"runs right" — column names, join paths and aggregates need checking against a
real database. But the database you check against may hold **real customs
declarations**: trader TINs, invoice values, inspection findings. You want the
model to get *"your query is valid, returns 42 rows with these 5 columns in
0.2s"* — and nothing else.

That is the entire design: **the model gets an oracle, not a window.**

## The four guarantees (and how each is enforced)

| # | Guarantee | Enforcement mechanism |
|---|-----------|----------------------|
| 1 | **Nothing can be written** | Every psql session is started with `PGOPTIONS="-c default_transaction_read_only=on"` — the *server* refuses INSERT/UPDATE/DELETE/DDL, even inside data-modifying CTEs (`WITH x AS (INSERT …)`). This holds even if a write slipped past the lexical guard. |
| 2 | **Only single SELECTs reach the DB** | A comment/string-aware scanner strips `'strings'`, `"identifiers"`, `$tag$…$tag$` blocks, `--` and `/* */` comments, then requires: one statement (no interior `;`), first keyword `SELECT`/`WITH`, no write/DDL/`COPY`/`CALL`/`DO`/`INTO` keywords. Literals can't smuggle keywords past it because they're removed before checking. |
| 3 | **No row data in any response** | Result *shape* comes from psql's `\gdesc`, which asks the server to *describe* the result (column names + types) **without executing**. Row *count* comes from wrapping your query: `SELECT count(*) FROM (<query>) AS __privacy_wrapper` — a single aggregate number crosses the wire. The tools have no code path that fetches rows. |
| 4 | **Queries can't run away** | `statement_timeout` (default **5 s**) is set server-side for the session, plus a hard subprocess kill. A `pg_sleep(60)` or an accidental cross join dies at 5 s. |

**What the model can still learn:** the *aggregate* row count of any query it
writes, plus the success/error oracle (e.g. a divide-by-zero probe). That is
inherent to any "does it run" checker. What it can never do through this server
is read a TIN, a name, a value, or any other cell.

## The three tools

| Tool | What it does | What comes back |
|------|--------------|-----------------|
| `describe_schema` | List tables, or one table's columns | Structure only (names, types, nullability) |
| `validate_query` | `EXPLAIN` the query — **no execution at all** | "VALID" + the plan, or the PostgreSQL error |
| `test_query` | Execute read-only, time-boxed | Column names/types, row count, duration — never rows |

A typical loop: `describe_schema` → write the query → `validate_query` (cheap,
no execution) → `test_query` (proves it runs and how many rows it returns).

## Install

No dependencies to install — the server is **pure Python stdlib** and shells
out to `psql` (which you already have if you loaded the schema).

Register it in your project's `.mcp.json` (this repo already ships one):

```json
{
  "mcpServers": {
    "customs-query-tester": {
      "command": "python3",
      "args": ["mcp/customs-query-tester/server.py"],
      "env": {
        "CUSTOMS_DB": "customs_sandbox",
        "CUSTOMS_SCHEMA": "asycuda"
      }
    }
  }
}
```

Copying it to another project: copy this folder, adjust the path in `args`,
point `CUSTOMS_DB` at your database (a name or a full
`postgresql://user@host:port/db` DSN — standard `PG*` environment variables
also apply).

### Configuration

| Setting | Env var / flag | Default |
|---------|----------------|---------|
| Database (name or DSN) | `CUSTOMS_DB` or `--db` | `customs_sandbox` |
| Schema (search_path) | `CUSTOMS_SCHEMA` or `--schema` | `asycuda` |
| Statement timeout (ms) | `CUSTOMS_TIMEOUT_MS` | `5000` |

### Harden it further (optional, recommended for real data)

The server enforces read-only *behaviour*; for defence in depth against real
customs data, also give it a **read-only role**:

```sql
CREATE ROLE query_tester LOGIN PASSWORD '…';
GRANT USAGE ON SCHEMA asycuda TO query_tester;
GRANT SELECT ON ALL TABLES IN SCHEMA asycuda TO query_tester;
```

…and point `CUSTOMS_DB` at a DSN using that role. Then even a server bug could
not write or escalate.

## How it talks MCP

Stdio transport, newline-delimited JSON-RPC 2.0. The server implements
`initialize`, `tools/list`, `tools/call` and `ping` — the minimum a client like
Claude Code needs. There is no HTTP listener, no network exposure: the client
spawns the process and owns its stdin/stdout.

## Relationship to the `customs-query` skill

The [`customs-query`](../../skills/customs-query/) Claude Code skill
teaches the model the schema's join paths and generates the SQL; this server is
its **verification arm**. If the MCP isn't connected, the skill falls back to
`scripts/test_query.sh`, which applies the *same* guarantees (read-only
session, `\gdesc`, count-only wrapper) through plain `psql`.

"""compile.py — turn a LOGICAL query (written against the toolbox's friendly
reconstruction names) into a GENUINE ASYCUDA World query you can actually run.

Mechanism — the "CTE prelude". For a logical query, we detect which logical
tables it references, then emit each one as a Common Table Expression that
SELECTs-and-aliases from the *real* ASYCUDA World tables (per the mapping), and
prepend those CTEs to the user's query. The user's SQL is left untouched; the
CTEs make the friendly names resolve to the wide, denormalised real schema.

The result is a single, standalone genuine Sydonia query — runnable anywhere,
no view-creation privilege required. The same mapping also drives the
persistent-view adapter (see emit_views).

Pure standard library except PyYAML (the mapping is human-edited YAML).
"""
from __future__ import annotations

import re
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError as exc:  # pragma: no cover
    raise SystemExit("compiler needs PyYAML — `pip install pyyaml`") from exc

MAPPINGS_DIR = Path(__file__).resolve().parent / "mappings"
PLACEHOLDER = re.compile(r"\{\{[^}]+\}\}")


# --------------------------------------------------------------------------
# Mapping
# --------------------------------------------------------------------------
def load_mapping(name: str = "asycuda-world", overrides: str | None = None) -> dict:
    """Load a base mapping (compiler/mappings/<name>.yml) and optionally deep-merge
    a per-instance overrides file over it."""
    base = _read_yaml(name if Path(name).suffix else MAPPINGS_DIR / f"{name}.yml")
    if overrides:
        _deep_merge(base, _read_yaml(overrides))
    return base


def _read_yaml(path) -> dict:
    p = Path(path)
    if not p.exists():
        raise SystemExit(f"mapping not found: {p}")
    return yaml.safe_load(p.read_text(encoding="utf-8")) or {}


def _deep_merge(base: dict, over: dict) -> dict:
    for k, v in (over or {}).items():
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            _deep_merge(base[k], v)
        else:
            base[k] = v
    return base


# --------------------------------------------------------------------------
# Literal-aware scanning (shared idea with mcp/customs-query-tester/server.py)
# --------------------------------------------------------------------------
def strip_literals(sql: str) -> str:
    """Blank out string/identifier literals and comments so table-name matching
    can't be fooled by their contents."""
    out, i, n = [], 0, len(sql)
    while i < n:
        ch = sql[i]
        nxt = sql[i + 1] if i + 1 < n else ""
        if ch == "-" and nxt == "-":
            j = sql.find("\n", i)
            i = n if j == -1 else j
        elif ch == "/" and nxt == "*":
            j = sql.find("*/", i + 2)
            i = n if j == -1 else j + 2
        elif ch == "'":
            i += 1
            while i < n and sql[i] != "'":
                i += 1
            i += 1
            out.append(" ")
        elif ch == '"':
            j = sql.find('"', i + 1)
            i = n if j == -1 else j + 1
            out.append(" ")
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def referenced_tables(sql: str, mapping: dict) -> list[str]:
    """Which logical tables from the mapping does this query mention?
    Ordered by the mapping's declaration order for stable, dependency-friendly output."""
    scanned = strip_literals(sql)
    hits = {
        name
        for name in mapping.get("tables", {})
        if re.search(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])", scanned, re.IGNORECASE)
    }
    return [name for name in mapping["tables"] if name in hits]


# --------------------------------------------------------------------------
# CTE construction
# --------------------------------------------------------------------------
def build_cte(name: str, spec: dict) -> str:
    """Render one logical table as a CTE over its real ASYCUDA World source."""
    if "raw" in spec:  # tables with no real catalogue (e.g. lanes) — literal body
        return f"  {name} AS (\n    {spec['raw'].strip()}\n  )"
    alias = spec.get("alias", "t")
    cols = spec["columns"]
    select_kw = "SELECT DISTINCT" if spec.get("distinct") else "SELECT"
    col_lines = [f"        {expr} AS {col}" for col, expr in cols.items()]
    body = [f"    {select_kw}", ",\n".join(col_lines), f"    FROM {spec['source']} {alias}"]

    where = []
    if "valid" in spec:  # UN*/xx*TAB reference tables carry VALID_FROM/VALID_TO
        v = spec["valid"]
        where.append(
            f"now()::date BETWEEN {v['from']} AND coalesce({v['to']}, DATE '9999-12-31')"
        )
    if spec.get("where"):
        where.append(f"({spec['where']})")
    if where:
        body.append("    WHERE " + " AND ".join(where))

    return f"  {name} AS (\n" + "\n".join(body) + "\n  )"


def compile_sql(logical_sql: str, mapping: dict) -> tuple[str, list[str]]:
    """Return (genuine_sql, warnings)."""
    tables = referenced_tables(logical_sql, mapping)
    if not tables:
        return logical_sql, ["no known logical tables referenced — returned unchanged"]

    ctes = [build_cte(t, mapping["tables"][t]) for t in tables]
    prelude = "WITH\n" + ",\n".join(ctes)

    body = logical_sql.strip()
    # strip a leading `SET search_path …;` — irrelevant once names are CTEs
    body = re.sub(r"^\s*SET\s+search_path[^;]*;\s*", "", body, flags=re.IGNORECASE)

    if re.match(r"^\s*WITH\b", body, re.IGNORECASE):
        # splice our CTEs in front of the user's existing WITH list
        genuine = re.sub(r"^\s*WITH\b", prelude + ",", body, count=1, flags=re.IGNORECASE)
    else:
        genuine = prelude + "\n" + body

    warnings = []
    unfilled = sorted(set(PLACEHOLDER.findall(genuine)))
    if unfilled:
        warnings.append(
            "compiled SQL still contains unfilled placeholders "
            f"({', '.join(unfilled)}) — supply a per-instance overrides file"
        )
    return genuine, warnings


# --------------------------------------------------------------------------
# Persistent-view adapter — the same mapping, emitted as CREATE VIEW
# --------------------------------------------------------------------------
def emit_views(mapping: dict, schema: str = "asycuda") -> str:
    lines = [
        f"-- Generated from compiler/mappings by `python -m compiler emit-views`.",
        f"-- Persistent compatibility views: our logical tables over the real ASYCUDA World schema.",
        f"CREATE SCHEMA IF NOT EXISTS {schema};",
        f"SET search_path TO {schema}, public;",
        "",
    ]
    for name, spec in mapping["tables"].items():
        cte = build_cte(name, spec)
        # reuse the CTE body inside a CREATE VIEW
        inner = cte.split(" AS (\n", 1)[1].rsplit("\n  )", 1)[0]
        lines.append(f"CREATE OR REPLACE VIEW {name} AS\n{inner};\n")
    return "\n".join(lines)

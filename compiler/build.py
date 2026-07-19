"""build.py — the high-level query BUILDER: turn a small, no-SQL query spec into
LOGICAL SQL (which compile.py then turns into genuine Sydonia SQL).

A spec is YAML/JSON — friendly for people who don't want to write SQL:

    from: declaration
    join:
      - declaration_item on declaration_item.declaration_id = declaration.id
      - declaration_tax_line on declaration_tax_line.declaration_item_id = declaration_item.id
    where:
      - declaration.selectivity_lane_id = 'RED'
    select:
      - declaration_item.hs_code
      - sum(declaration_tax_line.tax_amount) as taxes
    group_by: [declaration_item.hs_code]
    order_by: [taxes desc]
    limit: 10

It is deliberately thin — a convenience over logical SQL, not a new query
language. Anything it can't express, write as logical SQL directly.
"""
from __future__ import annotations

try:
    import yaml
except ModuleNotFoundError as exc:  # pragma: no cover
    raise SystemExit("builder needs PyYAML — `pip install pyyaml`") from exc


def _as_list(v):
    if v is None:
        return []
    return v if isinstance(v, list) else [v]


def build_logical_sql(spec: dict) -> str:
    if "from" not in spec or "select" not in spec:
        raise SystemExit("query spec needs at least `from:` and `select:`")

    parts = ["SELECT " + ",\n       ".join(_as_list(spec["select"]))]
    parts.append(f"FROM {spec['from']}")

    for j in _as_list(spec.get("join")):
        # accept "table on <cond>"  or  {table: t, on: cond}  or  {left join: ...}
        if isinstance(j, dict):
            kind = j.get("type", "JOIN").upper()
            parts.append(f"{kind} {j['table']} ON {j['on']}")
        else:
            table, _, cond = str(j).partition(" on ")
            parts.append(f"JOIN {table.strip()} ON {cond.strip()}")

    where = _as_list(spec.get("where"))
    if where:
        parts.append("WHERE " + "\n  AND ".join(where))
    if spec.get("group_by"):
        parts.append("GROUP BY " + ", ".join(_as_list(spec["group_by"])))
    if spec.get("having"):
        parts.append("HAVING " + "\n   AND ".join(_as_list(spec["having"])))
    if spec.get("order_by"):
        parts.append("ORDER BY " + ", ".join(_as_list(spec["order_by"])))
    if spec.get("limit") is not None:
        parts.append(f"LIMIT {int(spec['limit'])}")

    return "\n".join(parts) + ";"


def load_spec(path: str) -> dict:
    from pathlib import Path

    return yaml.safe_load(Path(path).read_text(encoding="utf-8"))

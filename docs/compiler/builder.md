---
title: The query builder
description: >-
  A small, no-SQL query spec that becomes logical SQL, then genuine ASYCUDA World
  SQL — friendly for people who don't want to write SQL by hand.
tags:
  - compiler
---

# The query builder

The **builder** turns a small, no-SQL **query spec** into logical SQL — which the
[compiler](logical-sql.md) then turns into genuine Sydonia SQL. It is deliberately
thin: a convenience over logical SQL for people who would rather describe a query
than write it, **not** a new query language.

```text
  query spec (YAML)  ──build──►  LOGICAL SQL  ──compile──►  GENUINE SYDONIA SQL
```

## The spec shape

A spec is YAML (or JSON). It maps directly onto the clauses of a `SELECT`:

```yaml
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
```

### The keys

Only `from` and `select` are required; everything else is optional. Each key
accepts a single value or a list.

| Key | Accepts | Becomes |
|-----|---------|---------|
| `from` | a logical table name (**required**) | `FROM <table>` |
| `select` | expression(s) (**required**) | `SELECT <expr>, …` |
| `join` | `"<table> on <condition>"` **or** a `{table, on, type}` object | `JOIN <table> ON <condition>` |
| `where` | condition(s), AND-ed | `WHERE … AND …` |
| `group_by` | expression(s) | `GROUP BY …` |
| `having` | condition(s), AND-ed | `HAVING … AND …` |
| `order_by` | expression(s) | `ORDER BY …` |
| `limit` | an integer | `LIMIT n` |

!!! note "Two ways to write a join"
    The string form `"declaration_item on declaration_item.declaration_id = declaration.id"`
    always produces an inner `JOIN`. For an outer join, use the object form and
    set `type`:
    ```yaml
    join:
      - table: inspection_act
        on: inspection_act.declaration_id = declaration.id
        type: left join
    ```

## Worked example — spec to logical to genuine

Run the builder on the spec above with `--logical` to see the generated
**logical SQL**:

```bash
python -m compiler build my_spec.yml --logical
```

```sql
SELECT declaration_item.hs_code,
       sum(declaration_tax_line.tax_amount) as taxes
FROM declaration
JOIN declaration_item ON declaration_item.declaration_id = declaration.id
JOIN declaration_tax_line ON declaration_tax_line.declaration_item_id = declaration_item.id
WHERE declaration.selectivity_lane_id = 'RED'
GROUP BY declaration_item.hs_code
ORDER BY taxes desc
LIMIT 10;
```

Drop the `--logical` flag and the same command runs it through the compiler to
produce **genuine Sydonia SQL** — the three referenced logical tables become
CTEs over `SAD_General_Segment`, `SAD_Item` and `SAD_Tax`, and your body is
left as written:

```bash
python -m compiler build my_spec.yml
```

```sql
WITH
  declaration AS (
    SELECT DISTINCT
        g.INSTANCE_ID AS id,
        …
        CASE WHEN g.PTY_RED = '1' THEN 'RED' … END AS selectivity_lane_id
    FROM SAD_General_Segment g
  ),
  declaration_item AS (
    SELECT
        i.INSTANCE_ID AS id,
        i.ITM_SGS_ID AS declaration_id,
        concat(i.TAR_HSC_NB1, i.TAR_HSC_NB2, i.TAR_HSC_NB3, i.TAR_HSC_NB4, i.TAR_HSC_NB5) AS hs_code,
        …
    FROM SAD_Item i
  ),
  declaration_tax_line AS (
    SELECT
        x.TAX_ITM_ID AS declaration_item_id,
        x.AMT AS tax_amount,
        …
    FROM SAD_Tax x
  )
SELECT declaration_item.hs_code,
       sum(declaration_tax_line.tax_amount) as taxes
FROM declaration
JOIN declaration_item ON declaration_item.declaration_id = declaration.id
JOIN declaration_tax_line ON declaration_tax_line.declaration_item_id = declaration_item.id
WHERE declaration.selectivity_lane_id = 'RED'
GROUP BY declaration_item.hs_code
ORDER BY taxes desc
LIMIT 10;
```

The builder and the compiler share the same `--mapping` and `--overrides`
options, so a spec targets a specific instance exactly the way raw logical SQL
does — see [the mapping](mapping.md).

## When to prefer raw logical SQL instead

The builder is intentionally minimal. Reach for **[logical SQL](logical-sql.md)**
directly whenever a query needs anything the spec can't express, including:

- **CTEs / `WITH`** — window-function preludes, pre-aggregation before a join
  (as in the [effective-rate](../guides/useful-queries.md) and league-table
  queries).
- **`LATERAL`** subqueries — e.g. the assessed-vs-paid reconciliation.
- **Window functions**, `FILTER (WHERE …)`, `percentile_cont`, `DISTINCT ON`, set
  operations, or anything else beyond the flat clause list above.

There is no loss of power in dropping to logical SQL — the compiler treats both
identically. The spec is simply the easiest on-ramp for straightforward
`from / join / where / select / group_by` reports.

## Related

- [Writing logical SQL](logical-sql.md) — the target of the builder, and the
  richer queries the spec can't cover.
- [The mapping](mapping.md) — how referenced tables resolve, and per-instance
  overrides.
- [Running the compiled SQL](running.md) — where to actually run the output.

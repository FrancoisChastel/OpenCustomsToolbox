---
title: Writing logical SQL
description: >-
  Author queries against the toolbox's friendly logical names, compile them from
  a file or stdin into genuine ASYCUDA World SQL, and see what the compiler
  detects and rewrites.
tags:
  - compiler
---

# Writing logical SQL

**Logical SQL is just SQL against the friendly names.** The names you use — the
tables and columns of the [reconstructed schema](../schema/index.md) —
`declaration`, `declaration_item`, `declaration_tax_line`, `ref_country`,
`hs_code`, `tax_amount` — are exactly the [logical layer](../schema/index.md) the
compiler maps *from*. If a query runs on the sandbox, it compiles.

!!! tip "You already know the names"
    Everything in the [querying guide](../guides/querying.md) and the
    [useful queries](../guides/useful-queries.md) library **is** logical SQL. Any
    of those queries can be piped straight through `compile`.

## The `compile` command

`compile` reads one logical SQL statement and prints the genuine Sydonia SQL. It
takes a **file**, or `-` for **stdin**:

```bash
# from a file
python -m compiler compile my_query.sql

# from stdin
echo "SELECT * FROM declaration WHERE selectivity_lane_id = 'RED'" \
  | python -m compiler compile -
```

Add `--logical` to stop *before* compiling and just echo the logical SQL back —
handy when the SQL comes from the [builder](builder.md) and you want to inspect
it first:

```bash
python -m compiler compile my_query.sql --logical
```

!!! note "One dependency"
    The compiler needs **PyYAML** (`pip install pyyaml`) to read the mapping.
    Nothing else — it is otherwise pure standard library.

## What the compiler detects and rewrites

The mechanism is the **CTE prelude**. The compiler:

1. **Scans** your query for logical table names — literal- and comment-aware, so
   a table name inside a string or a `--` comment never triggers a false match.
2. **Emits a CTE** for each referenced table, `SELECT`-ing and aliasing from the
   real ASYCUDA World source per the [mapping](mapping.md), in the mapping's
   declaration order (stable, dependency-friendly output).
3. **Prepends** those CTEs to your query. If your query already starts with
   `WITH`, the compiler *splices* its CTEs in front of your list rather than
   nesting a second `WITH`.
4. **Drops** a leading `SET search_path …;` — irrelevant once the friendly names
   are resolved by CTEs.

Your original `SELECT` body is otherwise left byte-for-byte unchanged.

## The gotchas it bakes in

Each CTE quietly handles a shape difference so your query never sees it:

| Real-schema gotcha | What the CTE does |
|--------------------|-------------------|
| Engine `INSTANCE_ID` keys | aliased `AS id` so surrogate-PK joins keep working |
| General segment repeated per item row | `declaration` is emitted `SELECT DISTINCT` — one row per declaration |
| HS code split `TAR_HSC_NB1..5` | `concat(...)` into a single `hs_code` |
| Code + name stored inline | `ref_*` CTEs are code-keyed (`id` := the business code) |
| `VALID_FROM` / `VALID_TO` on reference rows | a `WHERE now()::date BETWEEN …` validity filter |
| Colour flags `PTY_RED/YEL/GRE/BLU` | a `CASE` collapses them to a `selectivity_lane_id` code |

## A worked example — declaration header

The `declaration` logical table demaps the header's repetition and the colour
flags. This logical query:

```sql
SELECT id, registration_number, selectivity_lane_id
FROM declaration
WHERE selectivity_lane_id = 'RED';
```

compiles to (note `SELECT DISTINCT` and the injected `CASE`):

```sql
WITH
  declaration AS (
    SELECT DISTINCT
        g.INSTANCE_ID AS id,
        g.SGS_CUO_COD AS office_id,
        g.SGS_TYP_COD AS declaration_type_id,
        g.SGS_REG_NBR AS registration_number,
        g.SGS_REG_DAT AS registration_date,
        g.SGS_DEC_REF AS trader_reference,
        g.SGS_CNE_COD AS consignee_id,
        g.SGS_DCL_COD AS declarant_id,
        g.SGS_EXP_COD AS exporter_id,
        g.SGS_CUR_COD AS currency_id,
        g.SGS_INV_AMT AS total_invoice_amount,
        g.SGS_CIF_AMT AS total_cif_value,
        g.STA AS status_id,
        CASE WHEN g.PTY_RED = '1' THEN 'RED' WHEN g.PTY_YEL = '1' THEN 'YELLOW'
     WHEN g.PTY_GRE = '1' THEN 'GREEN' WHEN g.PTY_BLU = '1' THEN 'BLUE' END AS selectivity_lane_id
    FROM SAD_General_Segment g
  )
SELECT id, registration_number, selectivity_lane_id
FROM declaration
WHERE selectivity_lane_id = 'RED';
```

## A worked example — a reference table

Reference tables carry the validity filter automatically. This logical query:

```sql
SELECT c.name FROM ref_country c WHERE c.id = 'CN';
```

compiles to — the code-keyed `id`, the code-keyed `iso_alpha2`, and the
`VALID_FROM`/`VALID_TO` filter, all injected:

```sql
WITH
  ref_country AS (
    SELECT
        c.CTY_COD AS id,
        c.CTY_COD AS iso_alpha2,
        c.CTY_NAM AS name
    FROM UNCTYTAB c
    WHERE now()::date BETWEEN c.VALID_FROM AND coalesce(c.VALID_TO, DATE '9999-12-31')
  )
SELECT c.name FROM ref_country c WHERE c.id = 'CN';
```

!!! info "Placeholders warn, not fail"
    If the active mapping (base + [overrides](mapping.md)) still contains an
    unfilled `{{placeholder}}`, `compile` prints the SQL and emits a
    `-- warning:` on stderr naming the placeholders — a nudge to supply a
    per-instance overrides file, not a hard error.

## Test the result read-only

Compiled SQL is genuine Sydonia SQL — so validate it **before** you trust it on
real data. Both paths are **privacy-preserving**: they check the query against
schema metadata and a read-only plan, and never return row data.

```bash
# the bundled shell tester (read-only, metadata only)
skills/customs-query/scripts/test_query.sh "<your compiled SQL>"
```

The [`customs-query`](../skills/index.md) skill drives the same
**customs-query-tester** MCP from plain English — safe against a database holding
real customs declarations. See [Running the compiled SQL](running.md) for how to
point it at the sandbox, the mock database, or a real instance.

## Related

- [The query builder](builder.md) — generate logical SQL from a no-SQL spec.
- [The mapping](mapping.md) — what each logical name resolves to, and how to
  override it per instance.
- [Querying the model](../guides/querying.md) ·
  [Useful queries](../guides/useful-queries.md) — the logical query library.

---
title: The mapping
description: >-
  How each logical table maps to its real ASYCUDA World source, per-instance
  overrides that pin the non-public physical names, and materialising persistent
  compatibility views with emit-views.
tags:
  - compiler
---

# The mapping

The **mapping** is the single source of truth the compiler reads to build every
CTE — and the same file drives the persistent-view adapter. It lives at
[`compiler/mappings/asycuda-world.yml`](https://github.com/FrancoisChastel/OpenCustomsToolbox/blob/master/compiler/mappings/asycuda-world.yml)
and maps each of the toolbox's friendly logical tables to its real ASYCUDA World
source: the physical table, and for every logical column the physical expression
that produces it.

## The structure

Each entry under `tables:` describes one logical table. A typical entry:

```yaml
tables:
  declaration:
    source: SAD_General_Segment
    alias: g
    distinct: true            # AW repeats the general segment per item -> one row per declaration
    columns:
      id: g.INSTANCE_ID
      office_id: g.SGS_CUO_COD
      registration_number: g.SGS_REG_NBR
      status_id: g.STA
      selectivity_lane_id: >-
        CASE WHEN g.PTY_RED = '1' THEN 'RED' WHEN g.PTY_YEL = '1' THEN 'YELLOW'
             WHEN g.PTY_GRE = '1' THEN 'GREEN' WHEN g.PTY_BLU = '1' THEN 'BLUE' END
```

| Field | Meaning |
|-------|---------|
| `source` | the real AW physical table this logical table reads from |
| `alias` | the alias bound to that source inside the CTE (default `t`) |
| `columns` | a map of **logical → physical**: each logical column name to the SQL expression that produces it (`i.VIT_CIF`, a `concat(...)`, a `CASE`, …) |
| `distinct` | emit `SELECT DISTINCT` — used for `declaration`, whose header is repeated into every item row |
| `valid` | `{from:, to:}` — adds a `now()::date BETWEEN … AND coalesce(…, DATE '9999-12-31')` validity filter for `UN*`/`xx*TAB` reference tables |
| `where` | an extra predicate AND-ed into the CTE |
| `raw` | a literal CTE body used for tables with **no real catalogue** — e.g. selectivity lanes and declaration statuses are materialised from a `VALUES` list |

The compiler renders each entry as a CTE (`build_cte`) — that's the whole
mechanism. Column expressions are copied verbatim into the `SELECT`, aliased to
the logical name.

## What the default targets

The default mapping targets the **publicly-documented physical shape**. Some names
are pinned because the public docs fix them; the rest follow AW's prefix
conventions:

| Pinned from public docs | Following AW conventions (instance-specific) |
|-------------------------|----------------------------------------------|
| `SAD_Tax` roots `COD` / `BSE` / `RAT` / `AMT` / `MOP` / `TYP` | the `SGS_*` general-segment columns |
| `TAR_HSC_NB1..5` HS split | `SAD_STATUS_LOG`, `INSP_ACT_TAB`, `SEL_PARAM_TAB` names |
| `PTY_*` colour flags | the `UN*TAB` / `xx*TAB` reference table names |
| `VIT_CIF` / `VIT_STV` valuation build-up | operator/trader source `UNOPTAB` |
| `VALID_FROM` / `VALID_TO` on reference rows | |

!!! warning "Exact physical names are instance-specific"
    A **real** deployment's physical table and column names are
    version/instance-specific and **not public**. The defaults here are what the
    bundled [mock database](running.md) uses; for a real instance, pin the true
    names in a **per-instance overrides file**.

## Per-instance overrides

Overrides are a second YAML file **deep-merged over the base** mapping — you
override **only what differs**, and everything else is inherited. See
[`compiler/mappings/overrides.example.yml`](https://github.com/FrancoisChastel/OpenCustomsToolbox/blob/master/compiler/mappings/overrides.example.yml):

```yaml
# overrides.example.yml — only the differences
tables:
  declaration:
    source: SAD_GEN               # this instance calls it SAD_GEN
    columns:
      office_id: g.GEN_OFFICE     # override just this column's expression
  declaration_tax_line:
    source: SAD_TAXATION          # and the tax table SAD_TAXATION
    # COD/BSE/RAT/AMT/MOP are documented roots — usually no override needed
```

Pass it with `--overrides` on either `compile` or `build`:

```bash
python -m compiler compile q.sql --overrides compiler/mappings/myinstance.yml
```

The merge is recursive: setting `columns.office_id` for `declaration` replaces
**only that column's expression**, leaving every other column and every other
table exactly as the base mapping defines them.

!!! tip "Use the mock as your worked example"
    The default names line up with the bundled mock ASYCUDA World database. Get
    your compiled SQL running against the mock first; then write the overrides for
    the real instance — you are only changing names, not logic.

## Materialise persistent views with `emit-views`

The compiler prelude is per-query and needs no privileges. If instead you want
**persistent compatibility views** — logical tables physically present as
`CREATE VIEW` objects over the real schema, so *any* tool can query them —
`emit-views` renders the whole mapping as `CREATE OR REPLACE VIEW`:

```bash
python -m compiler emit-views > Sydonia/adapters/asycuda_world_compat.sql
python -m compiler emit-views --overrides compiler/mappings/myinstance.yml > my_compat.sql
```

It emits the schema preamble and one view per logical table (same CTE body,
wrapped as a view):

```sql
-- Generated from compiler/mappings by `python -m compiler emit-views`.
CREATE SCHEMA IF NOT EXISTS asycuda;
SET search_path TO asycuda, public;

CREATE OR REPLACE VIEW ref_country AS
    SELECT
        c.CTY_COD AS id,
        c.CTY_COD AS iso_alpha2,
        c.CTY_NAM AS name
    FROM UNCTYTAB c
    WHERE now()::date BETWEEN c.VALID_FROM AND coalesce(c.VALID_TO, DATE '9999-12-31');
```

This is the same adapter documented at
[running on a real ASYCUDA World](../platform/running-on-real-asycuda.md) — the
CTE prelude and the persistent views are two renderings of **one** mapping, so
they always agree.

## Related

- [Writing logical SQL](logical-sql.md) — the queries these mappings resolve.
- [Running the compiled SQL](running.md) — the sandbox, the mock database, and a
  real instance.
- [Running on a real ASYCUDA World](../platform/running-on-real-asycuda.md) — the
  deployment / FDW / ETL detail behind the persistent views.
- [Schema overview](../schema/index.md) — the logical layer these expressions map
  *from*.

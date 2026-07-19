---
title: Running on a real ASYCUDA World
description: >-
  How to run this toolbox's queries and skills against a live ASYCUDA World
  database — read-only compatibility views that adapt the wide, denormalised
  real schema to our normalised model, plus the ETL alternative for bulk work.
tags:
  - platform
---

# Running on a real ASYCUDA World

**The goal of this whole toolbox is to help you put your own ASYCUDA data to
work — for analytics, machine-learning risk models, and smarter selectivity.**
The reference schema, the queries and the skills are the vehicle; your live
ASYCUDA World database is the destination. This page is the bridge between them.

!!! tip "The easiest path: the query compiler"
    You usually don't need to hand-write the adapter below. The
    [**query compiler**](../compiler/index.md) compiles logical queries into
    genuine ASYCUDA World SQL on the fly (a CTE prelude, no view-creation
    privilege needed), and can also emit these persistent compatibility views for
    you (`emit-views`, with your per-instance overrides). Start there; this page is
    the deployment, FDW and ETL detail behind it — read on when you need the bulk
    ETL alternative or the cross-dialect / read-replica specifics.

!!! abstract "Why you're here"
    You want to analyse real declarations, engineer features, train a
    fraud / valuation model, or feed risk signals back into the clearance lanes —
    on *your* data. Put the bridge below in place once, and the
    [useful queries](../guides/useful-queries.md), the
    [`customs-query` skill](../skills/index.md), and the
    [ML risk-engine blueprint](../guides/ml-risk-engine.md) all run against the
    real system unchanged.

Everything in this toolbox is written against a **normalised reference model**:
`declaration`, `declaration_item`, `declaration_tax_line`, a wall of `ref_*`
code tables, snake_case names, surrogate `id` keys, foreign keys. That model is
readable and queryable — it is exactly what you want for analytics and ML.

A **real** ASYCUDA World database is the opposite. It is a **wide, denormalised**
physical schema optimised for the AW engine: `SAD_General_Segment`, `SAD_Item`,
`SAD_Tax`, `GEN_TAB`/`BOL_TAB`/`CTN_TAB`, `UN*`/`xx*TAB` reference tables. Codes
and their names are stored **inline** on the row (`GEN_CAR_COD` *and*
`GEN_CAR_NAM`), the general segment is **repeated into every item row**, keys are
engine `INSTANCE_ID` values, and the commodity code is **split across
`TAR_HSC_NB1..NB5`**.

And the deepest problem: **ASYCUDA World's physical schema is not public.** The
field-level model is documented only through the XML layer and national manuals
([XML messages](xml-messages.md)); the exact physical table and column names are
the [#1 "must-request" gap](integration.md). So this page describes an approach
that stays honest about that gap — you supply the last mile, once.

Two ways to bridge the two worlds — both in service of getting your data into
analytics, ML and selectivity:

- **Approach 1 — compatibility views** — run our queries, skills and feature
  extraction **live** on the real database.
- **Approach 2 — ETL into the reference model** — copy into a clean snapshot for
  **bulk analytics and model training**.

---

## Approach 1 — compatibility views (recommended for running our queries live)

Create **read-only views**, in schema `asycuda`, named **exactly** like our
tables, each one `SELECT`-ing and aliasing from the real AW tables. Because our
queries address tables unqualified via `search_path=asycuda,public`, and the
views carry our column names, **every query we write — and the whole
`customs-query` skill — runs unchanged** against the live system. No rewrites.

A worked mini-example. The declaration header comes from
`SAD_General_Segment`; note the de-duplication (AW repeats the general segment
into each item row) and the inline office code exposed as our `office_id`:

```sql
CREATE SCHEMA IF NOT EXISTS asycuda;
SET search_path TO asycuda, public;

-- our `declaration`  <-  AW SAD_General_Segment
CREATE OR REPLACE VIEW declaration AS
SELECT DISTINCT ON (g.INSTANCE_ID)
    g.INSTANCE_ID     AS id,                  -- engine key -> our surrogate id
    g.SGS_CUO_COD     AS office_id,           -- inline office code -> code-keyed ref_customs_office.id
    g.SGS_REG_NBR     AS registration_number,
    g.SGS_REG_DAT     AS registration_date,
    g.STA             AS status_id,           -- lifecycle STA code
    CASE                                       -- PTY colour flags -> our lane code
        WHEN g.PTY_RED = '1' THEN 'RED'
        WHEN g.PTY_YEL = '1' THEN 'YELLOW'
        WHEN g.PTY_GRE = '1' THEN 'GREEN'
        ELSE NULL
    END               AS selectivity_lane_id
    -- … the remaining columns of our declaration contract …
FROM SAD_General_Segment g                     -- TODO(instance): confirm real table name
ORDER BY g.INSTANCE_ID;
```

The tax lines come from `SAD_Tax`, whose field roots **`COD` / `BSE` / `RAT` /
`AMT` / `MOP`** are documented ([FIT.md](../provenance/fit.md),
[box 47](xml-messages.md)), so they map directly — no guessing:

```sql
-- our `declaration_tax_line`  <-  AW SAD_Tax
CREATE OR REPLACE VIEW declaration_tax_line AS
SELECT
    x.INSTANCE_ID     AS id,
    x.TAX_ITM_ID      AS declaration_item_id, -- TODO(instance): confirm link column
    x.COD             AS tax_type_id,         -- SAD_Tax COD  -> code-keyed ref_tax_type.id
    x.BSE             AS tax_base,            -- SAD_Tax BSE
    x.RAT             AS rate_percent,        -- SAD_Tax RAT (ad valorem)
    x.AMT             AS tax_amount,          -- SAD_Tax AMT
    x.MOP             AS mode_of_payment,     -- SAD_Tax MOP (1 payable / 0 guaranteed)
    (x.TYP = '1')     AS is_manual            -- SAD_Tax TYP manual/automatic flag
FROM SAD_Tax x;                                -- TODO(instance): confirm real table name
```

The full template — every core table (`ref_*`, `trader`, `declaration`,
`declaration_item`, `declaration_tax_line`, `manifest`, `bill_of_lading`,
`container`) — is in
[`Sydonia/adapters/asycuda_world_compat.sql`](https://github.com/FrancoisChastel/sydonia-toolkit/blob/master/Sydonia/adapters/asycuda_world_compat.sql),
with a [README](https://github.com/FrancoisChastel/sydonia-toolkit/blob/master/Sydonia/adapters/README.md)
covering the workflow.

!!! warning "The template will not run as-is"
    The physical column names are **instance/version-specific and non-public**.
    Every place the public docs don't pin an exact name is marked
    `-- TODO(instance):` for a DBA to fill once, using the real schema/ERD you
    [request](integration.md). The names that *are* pinned (`SAD_Tax`
    `COD`/`BSE`/`RAT`/`AMT`/`MOP`; the `GEN_*`/`BOL_*`/`SGS_*` prefixes) come
    from `FIT.md`/`xml-messages.md` and are your worked example.

!!! note "Read-only, so the privacy guarantees hold"
    Views are read-only; the adapter never writes to AW's own objects. So the
    [`customs-query-tester`](../skills/index.md) — which returns metadata only,
    never rows — stays safe even when `CUSTOMS_DB` points at a database holding
    real declarations.

**Not on PostgreSQL?** ASYCUDA World is database-agnostic (Oracle, MS SQL Server,
MySQL, PostgreSQL, DB2…). If the instance is on Oracle/MSSQL, either create the
equivalent views there in AW's own dialect, or stand up a Postgres front-end that
imports the real tables as **foreign tables** via `oracle_fdw` / `tds_fdw`, then
build these views on top. The view **contracts** (the column set each must
expose) are identical whichever route you take.

---

## Approach 2 — ETL into the reference model (for bulk analytics / ML)

Compatibility views are ideal for **running our queries live** on modest result
sets. For **bulk analytics or training data** — where you want a full local copy
in the clean normalised shape — copy the data instead of viewing through it:

1. **Extract** — from a **read-replica** (never primary), or from `<ASYCUDA>` /
   AWMDS XML exports produced by the client's *Export XML File* path.
2. **Transform** — reshape to our schema using the *same* `FIT.md` /
   `xml-messages.md` mapping. The adapter's `SELECT … AS …` lines are, in effect,
   the transform written out.
3. **Load** — into a separate Postgres carrying our `asycuda` schema
   ([load it](../guides/loading.md)).
4. **Query the copy** — now every skill, notebook and feature pipeline runs
   against a stable, normalised snapshot, decoupled from the live engine.

This is the path the [ML risk-engine guide](../guides/ml-risk-engine.md) assumes
for reading, feature-building and scoring at volume.

---

## The shape differences you must handle

Every divergence below is drawn from [`FIT.md`](../provenance/fit.md); the
adapter handles each one explicitly so your queries never have to.

| Aspect | Real ASYCUDA World | How the adapter handles it |
|--------|--------------------|----------------------------|
| **Table names** | terse codes — `GEN_TAB`, `BOL_TAB`, `SAD_General_Segment`, `SAD_Item`, `xxCTYTAB` | a view named like *our* table (`manifest`, `declaration`, `ref_country`) selects from each real source |
| **Coded fields** | code **and** name stored **inline** (`GEN_CAR_COD` + `GEN_CAR_NAM`) — no FK | `ref_*` views are **code-keyed** (`id` := the business code); operational views expose the inline code as our `*_id`, so `office_id = ref_customs_office.id` resolves on the code — no fabricated surrogate keys |
| **General segment repeated** | the general segment is copied into **every** `SAD_Item` row | the `declaration` header view **de-duplicates** (`SELECT DISTINCT ON (INSTANCE_ID)` / keyed header source) to one row per declaration |
| **Keys** | engine `INSTANCE_ID` / `InstanceId` | aliased **`AS id`** so our surrogate-PK joins keep working |
| **HS code** | split across `TAR_HSC_NB1..NB5` (national precision) | `declaration_item` **concatenates** the five parts into our single `hs_code` |
| **Reference validity** | `UN*`/`xx*TAB` rows carry `VALID_FROM` / `VALID_TO` | each `ref_*` view filters to current rows: `WHERE now()::date BETWEEN valid_from AND coalesce(valid_to, DATE '9999-12-31')` |
| **Taxes** | `SAD_Tax` with roots `COD`/`BSE`/`RAT`/`AMT`/`MOP`/`TYP` (+ `SAD_Ask_Tax`, `SAD_Global_Taxes`, `SAD_Tax_Totals`) | `declaration_tax_line` maps `COD→tax_type_id`, `BSE→tax_base`, `RAT→rate_percent`, `AMT→tax_amount`, `MOP→mode_of_payment`, `TYP→is_manual`; declaration/global totals stay **derived by query** |

---

## Privacy and safety

The adapter is read-only by construction, which is what makes it safe to point at
a database holding real declarations — trader TINs, invoice values, inspection
findings:

- **Views only** — no writes, no DDL against AW's own objects.
- Point **`CUSTOMS_DB`** at the real database, ideally via a **`SELECT`-only
  role** and a **read-replica**. A grant snippet ships at the bottom of the SQL
  template.
- The [`customs-query-tester`](../skills/index.md) then returns **metadata
  only** — column names/types, an aggregate row count, duration — and *never*
  row data. The model gets an oracle, not a window.

Set `CUSTOMS_DB` to the real DSN and `CUSTOMS_SCHEMA=asycuda` (or `compat` if you
created the views in a `compat` schema), and every skill behaves as it does on
the sandbox.

---

## What you must still obtain

The adapter is a faithful, well-annotated **contract** — but two things are
genuinely non-public and only your deployment can supply them:

1. **The real physical schema / column names** — the #1 gap. This is what turns
   every `-- TODO(instance)` into a real name. Request it via the channels on
   the [integration surfaces](integration.md) page.
2. **The deployment generation / version** — ASYCUDA++, World, or ASY5 — because
   the physical names differ between them. Confirm it against
   [version lineage](versions.md).

Once you have both, filling the template is mechanical, and the
`customs-query-tester` will confirm — **metadata only, no rows read** — that each
view's column set and join paths resolve against the live database.

---

## Related

- [Official fit & gap](../provenance/fit.md) — the table-by-table mapping the
  crib is grounded in.
- [XML messages & the wire format](xml-messages.md) — the SAD box → AW XML tag →
  our column three-way map.
- [Integration surfaces](integration.md) — the real doors, and what you must
  request.
- [Version lineage](versions.md) — telling which generation a deployment runs.
- [Querying guide](../guides/querying.md) ·
  [Useful queries](../guides/useful-queries.md) — the queries this adapter lets
  you run live.

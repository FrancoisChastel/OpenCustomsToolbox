---
title: Quickstart
description: From an empty database to a released customs declaration in one minute.
tags:
  - getting-started
---

# Quickstart

Load the model and run the end-to-end example against a throwaway PostgreSQL
database. Total time: about a minute.

## Prerequisites

- **PostgreSQL 14 or newer** (`psql`, `createdb` on your `PATH`).
- A local server you can create a database on. No superuser needed — an ordinary
  role that can `CREATE DATABASE` and `CREATE SCHEMA` is enough.

!!! tip "No local PostgreSQL?"
    Spin one up with Docker in one line:
    ```bash
    docker run --name customs -e POSTGRES_PASSWORD=customs -p 5432:5432 -d postgres:16
    ```
    Then prefix the commands below with the connection, e.g.
    `psql "postgresql://postgres:customs@localhost:5432/customs_sandbox" -f ...`.

## 1 · Get the files

```bash
git clone https://github.com/FrancoisChastel/sydonia-toolkit.git
cd sydonia-toolkit
```

The SQL lives under `Sydonia/`:

```text
Sydonia/schema/asycuda.sql          # the model — 55 tables, 8 modules
Sydonia/schema/seed_reference.sql   # reference / code-table seed data
Sydonia/examples/e2e.sql            # a full manifest → release worked example
```

## 2 · Create a database and load the model

```bash
createdb customs_sandbox

psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/schema/asycuda.sql
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/schema/seed_reference.sql
```

`-v ON_ERROR_STOP=1` makes `psql` exit non-zero on the first error, so a clean
run is a real signal. The schema creates and uses a dedicated **`asycuda`**
schema (namespace) — your `public` schema stays untouched.

## 3 · Run the end-to-end example

```bash
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/examples/e2e.sql
```

You should see a declaration assembled and reconciled:

```text
--- Declaration summary ---
  reg  | type |  status  | lane | total_items | total_cif_value
-------+------+----------+------+-------------+-----------------
 C 427 | IM4  | released | RED  |           2 |      63300.0000

--- Items with tax totals ---
 item_number | hs_code | customs_value |   taxes
-------------+---------+---------------+-----------
           1 | 851712  |    42200.0000 | 6541.0000
           2 | 610910  |    21100.0000 | 5591.5000

--- Total assessed vs receipt ---
 total_assessed | receipt_amount
----------------+----------------
     12132.5000 |     12132.5000

--- Lifecycle trail ---
 sort_order |    code    |                note
------------+------------+-------------------------------------
          1 | stored     | Draft captured
          2 | registered | Validated & registered (C 427)
          3 | assessed   | Assessed: duties & taxes calculated
          4 | paid       | Paid — receipt RCPT-2026-0427
          5 | released   | Release order issued
```

That is a complete import: a manifest arrives from Shanghai, a broker files an
IM4 declaration with two items, freight and insurance are apportioned to
per-item CIF, duty and VAT are assessed, selectivity routes it RED, an officer
inspects it, payment is receipted, and a release order is issued — all with
foreign keys intact.

## 4 · Look around

```bash
psql -d customs_sandbox
```

```sql
SET search_path TO asycuda, public;   -- (1)!

\dt                                     -- list the 55 tables
SELECT count(*) FROM declaration_item;  -- 2
\d+ declaration                         -- inspect the SAD general segment
```

1.  Every table lives in the `asycuda` schema. Set the `search_path` once per
    session and you can use bare table names.

## Next steps

<div class="grid cards" markdown>

-   :material-school: &nbsp;**Understand what you loaded** — the
    [customs concepts](concepts.md) primer maps the domain to the tables.

-   :material-magnify: &nbsp;**Start querying** — the
    [querying guide](../guides/querying.md) has the join paths and an analytics
    cookbook.

-   :material-map: &nbsp;**See the shape** — the
    [entity-relationship diagram](../schema/erd.md) renders every foreign key.

-   :material-check-decagram: &nbsp;**Trust it** — the
    [validation skill](../skills/index.md) re-runs the clean-load and provenance
    checks on demand.

</div>

## Tear it down

```bash
dropdb customs_sandbox
```

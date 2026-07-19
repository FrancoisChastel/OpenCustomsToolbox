---
title: Loading the schema
description: Integration patterns — CI, test resets, loading alongside your own tables.
tags:
  - guides
---

# Loading the schema

The [installation page](../getting-started/installation.md) covers first-time
setup. This guide is about **integrating loading into a workflow** — tests, CI,
and living alongside your application's own tables.

## Load order (always)

```text
1. Sydonia/schema/asycuda.sql          # schema + tables (drops & recreates `asycuda`)
2. Sydonia/schema/seed_reference.sql   # reference / code data
3. Sydonia/examples/e2e.sql            # optional worked example
```

`asycuda.sql` begins with `DROP SCHEMA IF EXISTS asycuda CASCADE;`, so **every
load is a clean reset** of the `asycuda` namespace.

## Living alongside your own tables

Because the model lives entirely in the `asycuda` schema, it coexists with your
application. Keep your tables in `public` (or your own schema); reference the
model explicitly or via `search_path`:

```sql
-- your app tables in public, the customs model in asycuda
SELECT d.registration_number, my.note
FROM asycuda.declaration d
JOIN public.my_annotations my ON my.declaration_id = d.id;
```

!!! warning "Reloading discards `asycuda` contents"
    Re-running `asycuda.sql` drops the whole `asycuda` schema. Never put data you
    want to keep **inside** `asycuda` — keep it in your own schema and reference
    across.

## Reset between tests

The idempotent load makes per-suite resets trivial:

```bash
# fast reset: reload schema + seed only (skip the e2e example)
psql -v ON_ERROR_STOP=1 -d "$TEST_DB" -f Sydonia/schema/asycuda.sql
psql -v ON_ERROR_STOP=1 -d "$TEST_DB" -f Sydonia/schema/seed_reference.sql
```

For many fast resets, `DROP SCHEMA asycuda CASCADE;` + reload is cheaper than
recreating the database.

## Continuous integration

A minimal GitHub Actions job that proves a clean load on every push:

```yaml
jobs:
  load:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env: { POSTGRES_PASSWORD: postgres }
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready --health-interval 10s
          --health-timeout 5s --health-retries 5
    env:
      PGPASSWORD: postgres
      PSQL: psql -v ON_ERROR_STOP=1 -h localhost -U postgres -d customs
    steps:
      - uses: actions/checkout@v4
      - run: createdb -h localhost -U postgres customs
      - run: $PSQL -f Sydonia/schema/asycuda.sql
      - run: $PSQL -f Sydonia/schema/seed_reference.sql
      - run: $PSQL -f Sydonia/examples/e2e.sql
```

The [`customs-validate`](../skills/index.md) skill wraps exactly this check for
local use.

## Loading into a specific schema name

Prefer a different namespace? The model hardcodes `asycuda`, but you can rename
after loading, or `sed` the three `asycuda` references at the top of the file:

```bash
sed 's/\basycuda\b/customs/g' Sydonia/schema/asycuda.sql | psql -v ON_ERROR_STOP=1 -d mydb -f -
# remember to apply the same rename to seed_reference.sql and e2e.sql (their SET search_path lines)
```

## Verify the load programmatically

```sql
SET search_path TO asycuda, public;
SELECT
  (SELECT count(*) FROM information_schema.tables
   WHERE table_schema='asycuda' AND table_type='BASE TABLE') AS tables,      -- 55
  (SELECT count(*) FROM ref_transport_mode) AS transport_modes,              -- 9
  (SELECT count(*) FROM ref_selectivity_lane) AS lanes;                      -- 4
```

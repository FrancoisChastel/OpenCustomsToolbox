---
title: Installation
description: Prerequisites, PostgreSQL setup, the asycuda schema, reloads and teardown.
tags:
  - getting-started
---

# Installation

The model is plain SQL — there is nothing to compile and no runtime dependency
beyond PostgreSQL itself.

## Requirements

| Requirement | Notes |
|-------------|-------|
| **PostgreSQL 14+** | The schema deliberately avoids 15-only features so it loads on 14. Tested on 14–16. |
| `psql` + `createdb` | Ships with any PostgreSQL client install. |
| A role that can `CREATE DATABASE` / `CREATE SCHEMA` | No superuser required. |

## The three SQL files (and load order)

Order matters — objects reference each other:

```text
1. Sydonia/schema/asycuda.sql          creates schema `asycuda` + 55 tables + indexes
2. Sydonia/schema/seed_reference.sql   fills the ref_* / code tables
3. Sydonia/examples/e2e.sql            (optional) a worked manifest → release example
```

Load them with `ON_ERROR_STOP=1` so any problem fails loudly:

```bash
createdb customs_sandbox
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/schema/asycuda.sql
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/schema/seed_reference.sql
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/examples/e2e.sql   # optional
```

## The `asycuda` schema

Everything is created inside a dedicated PostgreSQL **schema** (namespace)
called `asycuda`, not in `public`. This keeps the model self-contained and easy
to drop, and lets it coexist with your own tables.

```sql
-- from asycuda.sql
DROP SCHEMA IF EXISTS asycuda CASCADE;   -- (1)!
CREATE SCHEMA asycuda;
SET search_path TO asycuda, public;
```

1.  The load is **idempotent**: re-running `asycuda.sql` drops and recreates the
    whole schema, so you always get a clean slate. Anything you put *inside*
    `asycuda` is discarded on reload — keep your own tables elsewhere.

To use bare table names in a session, set the search path once:

```sql
SET search_path TO asycuda, public;
SELECT count(*) FROM declaration;   -- instead of asycuda.declaration
```

To make it the default for a database or role:

```sql
ALTER DATABASE customs_sandbox SET search_path TO asycuda, public;
```

## Verify the load

```sql
SET search_path TO asycuda, public;

-- 55 base tables expected
SELECT count(*) FROM information_schema.tables
WHERE table_schema = 'asycuda' AND table_type = 'BASE TABLE';

-- reference data present (transport modes, statuses, lanes, …)
SELECT count(*) FROM ref_transport_mode;   -- 9
SELECT code, name FROM ref_selectivity_lane ORDER BY code;
```

!!! success "What a clean install looks like"
    `asycuda.sql` and `seed_reference.sql` complete with **zero errors**, the
    table count is **55**, and `e2e.sql` prints the declaration summary with
    `total_assessed = receipt_amount`. Anything else is a real failure — read the
    `psql` output.

## Docker one-liner

```bash
docker run --name customs -e POSTGRES_PASSWORD=customs -p 5432:5432 -d postgres:16
export PGURL="postgresql://postgres:customs@localhost:5432"

createdb "$PGURL/customs_sandbox" 2>/dev/null || \
  psql "$PGURL/postgres" -c 'CREATE DATABASE customs_sandbox;'

for f in schema/asycuda.sql schema/seed_reference.sql examples/e2e.sql; do
  psql -v ON_ERROR_STOP=1 "$PGURL/customs_sandbox" -f "Sydonia/$f"
done
```

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `permission denied to create database` | Use a role with `CREATEDB`, or create the DB as an admin and load into it. |
| `schema "asycuda" already exists` errors mid-file | You edited the file and removed the `DROP SCHEMA` guard — restore it, or `DROP SCHEMA asycuda CASCADE;` first. |
| `relation "…" does not exist` in the seed/e2e | Files loaded out of order — always load `asycuda.sql` **first**. |
| Bare table names "not found" in `psql` | Run `SET search_path TO asycuda, public;` for the session. |
| Syntax errors on `GENERATED ALWAYS AS IDENTITY` | Your server is < PostgreSQL 10 — upgrade; the model targets 14+. |

## Automate it with an agent

The [`customs-schema-setup`](../skills/index.md) Agent Skill does all of the
above for you — creating the database, loading the files in order, and reporting
a clean/failed result — and [`customs-validate`](../skills/index.md) re-runs the
full done-condition checks. The skills install into any agent (Claude Code,
Cursor, Codex, …) via `npx skills add`.

## Tear it down

```bash
dropdb customs_sandbox
# or, to keep the database but drop just the model:
psql -d customs_sandbox -c 'DROP SCHEMA asycuda CASCADE;'
```

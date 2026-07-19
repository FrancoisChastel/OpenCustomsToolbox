---
name: customs-schema-setup
description: >-
  Set up, install, load, bootstrap or reset the Open Customs Toolbox ASYCUDA /
  SYDONIA PostgreSQL reference schema in a database. Creates the database, loads
  the schema then the reference seed then (optionally) the end-to-end example in
  the correct order, and reports a clean or failed result. Use when the user
  wants to stand up a customs sandbox, load the customs data model, or reset it.
---

# Customs schema setup

Stand the customs data model up in PostgreSQL. The model is plain SQL in
`Sydonia/schema/` and loads into a dedicated `asycuda` schema (namespace), so it
never touches the user's `public` schema.

## When to use

Trigger on requests like "set up / install / load / bootstrap / reset the customs
schema (or sandbox)", or before any task that needs the model present in a
database (querying, seeding, validating).

## Prerequisites (check first)

- `psql` and `createdb` on `PATH` (PostgreSQL **14+**). If missing, tell the user
  and stop — do not attempt to install PostgreSQL for them.
- A reachable server and a role that can `CREATE DATABASE` / `CREATE SCHEMA`.
- The model files present. Locate `Sydonia/schema/asycuda.sql` from the project
  root; if the toolbox lives elsewhere, ask for the path and pass `--schema-dir`.

## How to run

Use the bundled loader — it enforces load order and `ON_ERROR_STOP=1`:

```bash
bash .claude/skills/customs-schema-setup/scripts/load.sh [DB_NAME] [options]
```

Options:

| Flag | Default | Meaning |
|------|---------|---------|
| `DB_NAME` (positional) | `customs_sandbox` | Database to create/load into |
| `--schema-dir DIR` | auto-detected `Sydonia/schema` | Where `asycuda.sql` + `seed_reference.sql` live |
| `--examples-dir DIR` | sibling `Sydonia/examples` | Where `e2e.sql` lives |
| `--no-e2e` | (off) | Load schema + seed only, skip the worked example |
| `--keep` | (off) | Do not drop an existing database first |

Connection follows standard `libpq` env vars (`PGHOST`, `PGPORT`, `PGUSER`,
`PGPASSWORD`, `PGDATABASE`) — pass them through for Docker/remote servers.

## What a good result looks like

`asycuda.sql` and `seed_reference.sql` complete with **zero errors**; the table
count is **55**; and (unless `--no-e2e`) the example prints a declaration whose
`total_assessed` equals `receipt_amount`. Report the table count and the
assessed/receipt line back to the user. Anything else is a real failure — surface
the `psql` error, do not paper over it.

## After setup

- Set `search_path` before querying: `SET search_path TO asycuda, public;`
- To query the model, use the **customs-query** skill.
- To confirm it is clean and fully sourced, use the **customs-validate** skill.
- Tear down with `dropdb DB_NAME`, or `DROP SCHEMA asycuda CASCADE;` to keep the DB.

## Notes

- The load is **idempotent**: `asycuda.sql` starts with `DROP SCHEMA IF EXISTS
  asycuda CASCADE;`, so re-running gives a clean slate. Never store the user's own
  data inside the `asycuda` schema.
- Do not edit the SQL to "make it load" — if it fails on the user's server,
  diagnose (version, permissions, order) rather than mutating the model.

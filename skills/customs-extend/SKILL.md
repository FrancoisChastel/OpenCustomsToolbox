---
name: customs-extend
description: >-
  Add or modify tables and columns in the Sydonia Toolkit customs schema
  while preserving its conventions (snake_case, ref_/sys_ prefixes, identity PKs,
  FK-to-ref coded columns, numeric money/mass types) and — critically — its
  provenance trail (every CREATE TABLE tagged -- src: or -- inferred, coverage
  updated). Use when the user wants to extend, customise, add a table/column to,
  or adapt the customs / ASYCUDA schema for their own needs.
---

# Customs extend

Grow the schema without eroding what makes it trustworthy: consistent
conventions and an honest provenance trail. Read `reference/conventions.md` for
the full rulebook; this is the workflow.

## When to use

"Add a table/column", "extend/customise the schema", "model X in the customs
data", "adapt this for our country's fields". For pure data (rows), use
**customs-seed** instead.

## Workflow

1. **Decide provenance honestly.** Is this grounded in a document you actually
   have (cite its `SOURCES.md` ID), or is it your modelling judgement (`inferred`)?
   Never invent a citation. A larger honest inferred set beats a fabricated
   documented one.

2. **Write the DDL to convention** (full list in `reference/conventions.md`):
   - Schema-qualify `asycuda.` (or rely on the file's `SET search_path`).
   - `snake_case`; `ref_` for code tables, `sys_` for system/RBAC.
   - `id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`.
   - Real business codes `UNIQUE NOT NULL`.
   - Coded columns → **FK to a `ref_*` table**, not an inline code+name pair.
   - Money `numeric(18,4)`; mass/qty `numeric(18,3)`; flags `boolean`; times
     `timestamptz`.
   - Status lifecycle → a `ref_*_status` table + a `*_status_history` child.
   - `COMMENT ON` anything non-obvious.

3. **Tag it.** Put exactly one provenance line directly above the `CREATE TABLE`:
   ```sql
   -- src: S014, S003          -- OR --          -- inferred
   CREATE TABLE asycuda.new_thing ( ... );
   ```
   Tag individually-inferred columns inline too.

4. **Place it in the right module** of `Sydonia/schema/asycuda.sql` (the file is
   ordered Reference → Traders → Manifest → Declaration → Selectivity →
   Accounting → Transit → Audit), respecting FK dependency order. Use a deferred
   `ALTER TABLE … ADD CONSTRAINT` for forward references (see how
   `declaration_item.warehouse_id` is wired).

5. **Update the docs in the same change:**
   - `SOURCES.md` — add any new cited source (ID, URL, note) **and** cache a copy
     under `sources/`.
   - `COVERAGE.md` — add the table under its module, marked documented/partial/inferred.
   - `DATA_DICTIONARY.md` — regenerate from the catalog (it is generated).

6. **Re-validate.** Run the **customs-validate** skill (or reload + grep) to
   confirm the schema still loads clean and every table is still tagged.

## Guardrails

- Do not drop or rename existing tables/columns to "simplify" unless asked —
  other objects and the e2e example depend on them.
- Do not disable constraints to make something fit; model it correctly.
- Keep the model in the `asycuda` schema; don't scatter objects into `public`.

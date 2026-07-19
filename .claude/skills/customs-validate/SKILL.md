---
name: customs-validate
description: >-
  Validate, verify or audit the Open Customs Toolbox customs schema against its
  done-conditions — a clean load (schema + seed + end-to-end example, zero
  errors), every table carrying a provenance tag, and every cited source ID
  resolving in SOURCES.md. Use when the user wants to check the schema still
  loads cleanly, confirm it is fully grounded/sourced, or audit a fork after
  changes before committing.
---

# Customs validate

Re-run the project's four done-conditions and report a PASS/FAIL. This is the
auditable green light after any change, and the honest check before a commit.

## When to use

Trigger on "validate / verify / audit / check the customs schema", after using
**customs-extend** or **customs-seed**, or whenever someone asks "is it still
clean and fully sourced?".

## How to run

The bundled script does everything against a throwaway database and cleans up
after itself:

```bash
bash .claude/skills/customs-validate/scripts/verify.sh [--sydonia-dir DIR] [--db NAME]
```

- Auto-detects the `Sydonia/` directory from the project root; pass
  `--sydonia-dir` if it lives elsewhere.
- Requires `psql` + `createdb` (PostgreSQL 14+). If absent, it still runs the
  **static** checks (provenance tags, source resolution) and clearly reports that
  the load check was skipped.

## The four checks

1. **Schema loads clean.** `asycuda.sql` → `seed_reference.sql` → `examples/e2e.sql`
   against a fresh database with `ON_ERROR_STOP=1`, zero errors, and the e2e
   example inserts (assessed total equals the receipt).
2. **Every table is grounded.** Every `CREATE TABLE` in `schema/*.sql` has a
   preceding `-- src: <ID>` or `-- inferred`. Zero untagged tables.
3. **Every source resolves.** Each `<ID>` cited in the schema has a row in
   `SOURCES.md`. (The script also flags IDs with no cached file under `sources/`
   or `docs/`.)
4. **Docs present.** `DATA_DICTIONARY.md`, `ERD.md`, `COVERAGE.md`,
   `RESEARCH_LOG.md` exist.

## Interpreting the result

- **All PASS** → report the table count (expect 55), the documented/inferred
  split, and the assessed=receipt line. Safe to commit.
- **Any FAIL** → surface the exact failure (the untagged table, the unresolved
  ID, or the `psql` error) and stop. Do **not** "fix" a failure by loosening a
  check or inventing a citation — that defeats the purpose. If a new table is
  genuinely unsourced, it must be tagged `-- inferred` and noted in `COVERAGE.md`
  (use the **customs-extend** skill).

## Notes

This mirrors the acceptance checks in `Sydonia/SYDONIA-GOAL.md` §1. Keep them
honest: a larger truthful **inferred** set is always preferred over a fabricated
**documented** one.

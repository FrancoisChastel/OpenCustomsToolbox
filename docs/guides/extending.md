---
title: Extending the schema
description: Add tables and columns while keeping conventions and provenance intact.
tags:
  - guides
  - extending
---

# Extending the schema

The model is a starting point. When you add to it, keep two things intact: the
**conventions** (so it stays consistent) and the **provenance trail** (so your
fork stays as auditable as the original).

## The conventions, as a checklist

When adding a table or column:

- [ ] Live in the `asycuda` schema (the load already `SET search_path`).
- [ ] `snake_case` names; `ref_` prefix for code tables, `sys_` for system/RBAC.
- [ ] Surrogate PK: `bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`.
- [ ] Keep real business codes as `UNIQUE NOT NULL` (don't rely on the surrogate).
- [ ] Coded columns are a **foreign key to a `ref_*` table**, not an inline
      code+name pair.
- [ ] Money `numeric(18,4)`; mass/quantity `numeric(18,3)`; dates `date` /
      `timestamptz`; flags real `boolean`.
- [ ] A status lifecycle → a `ref_*_status` table + a `*_status_history` child.
- [ ] `COMMENT ON` anything non-obvious.
- [ ] **Tag provenance** on the `CREATE TABLE` (see below).

## Provenance is the rule that makes this project trustworthy

Every `CREATE TABLE` carries exactly one provenance tag on the line above it:

```sql
-- src: S014, S003        (cite the SOURCES.md IDs the table is grounded in)
CREATE TABLE declaration_item ( ... );

-- inferred               (introduced by your own modelling judgement)
CREATE TABLE trader_role ( ... );
```

The rule from the project goal is worth repeating:

!!! quote
    A larger honest **inferred** set beats a fabricated **documented** one. If you
    can't ground a table in a source you actually have, tag it `-- inferred` and
    record it in `COVERAGE.md` — never invent a citation.

Individually inferred columns inside an otherwise-documented table get their own
inline `-- inferred` note too.

## Worked change — add a table and a column

Say you want to model **container gate movements** (a new concept) and add a
**customs-value-method note** column to items.

**1 · Add the column** (documented — it maps to SAD box 43):

```sql
-- src: S003   (SAD box 43 valuation method note)
ALTER TABLE declaration_item
    ADD COLUMN valuation_method_note varchar(200);
COMMENT ON COLUMN declaration_item.valuation_method_note
    IS 'Free-text note on the valuation method chosen (SAD box 43).';
```

**2 · Add the table** (inferred — no public source at this granularity):

```sql
-- inferred   (gate in/out events are operational; not in the reference docs)
CREATE TABLE asycuda.container_gate_move (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    container_id  bigint NOT NULL REFERENCES container(id) ON DELETE CASCADE,
    direction     varchar(3) NOT NULL,          -- in / out
    moved_at      timestamptz NOT NULL DEFAULT now(),
    office_id     bigint REFERENCES ref_customs_office(id),
    CONSTRAINT ck_gate_dir CHECK (direction IN ('in','out'))
);
COMMENT ON TABLE asycuda.container_gate_move
    IS 'Container gate in/out events at a customs office; inferred.';
```

## Keep the docs in lock-step

Three files are the audit surface — update them in the same change:

| File | Update |
|------|--------|
| `SOURCES.md` | Add any **new** source ID you cited (with URL, note, and a cached copy under `sources/`). |
| `COVERAGE.md` | Add the new table under its module, marked `documented` / `partial` / `inferred`. |
| `DATA_DICTIONARY.md` | Regenerate from the catalog (it is generated, not hand-written). |

## Verify nothing broke

Re-run the load and the done-condition checks after any change:

```bash
createdb oct_check
psql -v ON_ERROR_STOP=1 -d oct_check -f Sydonia/schema/asycuda.sql
psql -v ON_ERROR_STOP=1 -d oct_check -f Sydonia/schema/seed_reference.sql
psql -v ON_ERROR_STOP=1 -d oct_check -f Sydonia/examples/e2e.sql
dropdb oct_check

# every CREATE TABLE must still carry a provenance tag:
grep -niE 'create[ \t]+table' Sydonia/schema/asycuda.sql | wc -l
```

!!! tip "Let an Agent Skill enforce this"
    The [`customs-extend`](../skills/index.md) skill applies this whole checklist —
    conventions, provenance tag, doc updates, and a re-load — for you, and
    [`customs-validate`](../skills/index.md) confirms the schema still loads clean
    and every table is grounded.

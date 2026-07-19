# Schema conventions — the rulebook

The full set of conventions the Sydonia Toolkit schema follows. Keep these
when extending it so a fork reads like the original and stays auditable.

## Namespace

- Everything lives in the PostgreSQL schema **`asycuda`** (not `public`).
- `schema/asycuda.sql` sets `SET search_path TO asycuda, public;` once at the top;
  new DDL in that file inherits it. Standalone scripts must set it themselves.

## Naming

| Thing | Rule | Example |
|-------|------|---------|
| Tables/columns | `snake_case` | `declaration_item` |
| Code/reference tables | `ref_` prefix | `ref_country`, `ref_tax_type` |
| System / RBAC tables | `sys_` prefix | `sys_user`, `sys_role` |
| Status catalogues | `ref_<thing>_status` | `ref_declaration_status` |
| Status history | `<thing>_status_history` | `declaration_status_history` |
| Foreign-key columns | `<referenced>_id` | `office_id`, `tax_type_id` |

## Keys

- **Primary key:** surrogate `id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`.
- **Business keys:** keep the real code (HS, office code, TIN, receipt number)
  as a separate `UNIQUE NOT NULL` column — never overload the surrogate id with
  business meaning.
- **Junctions** (M:N) use a composite PK of the two FKs (see `sys_user_role`).

## Coded columns → foreign keys

A coded value is a **foreign key to its `ref_*` table**, not an inline
`code + name` pair. This is the deliberate normalisation that distinguishes this
reference model from the wide/denormalised official physical schema.

```sql
-- do this
office_id  bigint NOT NULL REFERENCES ref_customs_office(id)
-- not this
office_code varchar(5), office_name varchar(120)
```

Where a small fixed domain has no `ref_` table, use a `CHECK (... IN (...))`
(see `account.account_type`, `account_movement.movement_type`).

## Data types

| Kind | Type |
|------|------|
| Money / value / tax | `numeric(18,4)` |
| Mass / quantity | `numeric(18,3)` |
| Rate (percent) | `numeric(9,4)` |
| Codes | `varchar(n)` sized to the standard |
| Dates | `date` |
| Timestamps | `timestamptz` (default `now()` for event times) |
| Flags | real `boolean` (not `char(1)`) |

## Status lifecycles

Model a lifecycle as a `ref_*_status` catalogue (with a `sort_order`) plus a
`*_status_history` child that records each transition (status, `changed_at`,
`changed_by`, note). Keep the **current** status denormalised on the parent
(`declaration.status_id`) for fast filtering.

## Referential actions

- Child rows that are meaningless without their parent use `ON DELETE CASCADE`
  (e.g. `declaration_item → declaration`).
- Lookups and cross-references omit cascade (default `NO ACTION`).
- Forward references (a column that points to a table defined later in the file)
  are added with a deferred `ALTER TABLE … ADD CONSTRAINT` after both exist — see
  `declaration_item.warehouse_id → ref_warehouse`.

## Comments

`COMMENT ON TABLE` (and `COMMENT ON COLUMN` for non-obvious columns) with a
one-line purpose and the SAD box / source where relevant. These feed the
generated `DATA_DICTIONARY.md`.

## Provenance (the rule that matters most)

Exactly one tag on the line directly above every `CREATE TABLE`:

```sql
-- src: S014, S003        (grounded in these SOURCES.md IDs)
-- inferred               (your modelling judgement; no public source)
```

- Individually inferred columns inside a documented table get an inline
  `-- inferred` note.
- **Never fabricate a citation.** If you can't ground it, tag `-- inferred` and
  record it in `COVERAGE.md`. A larger honest inferred set beats a fabricated
  documented one.

## The three docs to update with any structural change

| File | What |
|------|------|
| `SOURCES.md` | New cited source: ID, URL, one-line note — and cache a copy under `sources/`. |
| `COVERAGE.md` | New table under its module, marked documented / partial / inferred. |
| `DATA_DICTIONARY.md` | Regenerate from the live catalog (it is generated, not hand-edited). |

## Verify

Reload into a scratch DB and re-run the done-conditions (the **customs-validate**
skill): clean load, every table tagged, every cited ID resolves.

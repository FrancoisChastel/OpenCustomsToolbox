---
name: customs-query
description: >-
  Write correct SQL against the Open Customs Toolbox ASYCUDA / SYDONIA customs
  model — reports, lookups, reconciliations and analytics. Knows the `asycuda`
  schema search_path, that coded columns are foreign keys to ref_* tables, that
  totals are derived (not stored), and the canonical join paths (declaration →
  item → tax line; manifest → bill of lading → cargo). Use when the user asks for
  a query, report, or number from the customs / declaration / manifest data.
---

# Customs query

Turn a plain-English question about the customs data into a correct PostgreSQL
query. The model is normalised, so two rules govern almost everything.

## Two rules to always apply

1. **Set the search path.** Every table is in the `asycuda` schema:
   ```sql
   SET search_path TO asycuda, public;
   ```
2. **Coded columns are foreign keys.** To show a code's *name*, join its `ref_*`
   table (e.g. `d.declaration_type_id → ref_declaration_type`). Totals like
   "total tax" are **derived by aggregation**, not stored — sum
   `declaration_tax_line.tax_amount`.

## The model map

Two spines carry most queries:

```text
manifest → bill_of_lading → container / manifest_cargo_item      (cargo)
declaration → declaration_item → declaration_tax_line            (declaration)
                             ↘ item_value_note (per-item CIF)
```

Key tables by intent:

| Want… | Start from |
|-------|------------|
| Declarations, parties, regime, status, lane | `declaration` (+ `ref_*`, `trader`) |
| Line items, HS codes, customs value | `declaration_item` |
| Duty/VAT/excise per line | `declaration_tax_line` (+ `ref_tax_type`) |
| Manifests, voyages, bills of lading, cargo | `manifest`, `bill_of_lading`, `manifest_cargo_item` |
| Payments, receipts, accounts | `payment`, `receipt`, `account` |
| Risk lanes, inspections | `selectivity_result`, `inspection_act`, `ref_selectivity_lane` |
| Lifecycle history | `declaration_status_history` (+ `ref_declaration_status`) |

## How to write the query

1. Identify the spine and the `ref_*` tables needed to resolve codes.
2. Join along foreign keys (see `reference/cookbook.sql` for the exact paths).
3. Aggregate for any total; filter by `trader_reference`, `registration_number`,
   dates, HS prefix, or lane as asked.
4. Prefer set-based SQL; add `ORDER BY` for readable output.

The bundled **`reference/cookbook.sql`** has ready, annotated queries for the
common cases (full declaration assembly, items-with-taxes, cargo listing,
assessed-vs-paid, revenue by HS/tax, lane throughput, write-off tracing,
warehouse stock). Adapt the closest one rather than starting from scratch.

## Explore when unsure

If a column name is uncertain, inspect rather than guess:

```sql
SET search_path TO asycuda, public;
\d+ declaration          -- columns, types, FKs of one table
\dt                      -- all 55 tables
```

The full column reference is `Sydonia/DATA_DICTIONARY.md`.

## Pitfalls

- Forgetting the `search_path` → "relation does not exist". Set it first.
- Selecting a `*_id` and expecting a label → join the `ref_*` table.
- Summing `tax_base` instead of `tax_amount` for revenue.
- VAT cascades (its base includes duty) — don't re-derive tax; read
  `declaration_tax_line`.
- Money is `numeric(18,4)`; don't cast to float for reporting.

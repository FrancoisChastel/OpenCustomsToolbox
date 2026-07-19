---
name: customs-query
description: >-
  Generate correct SQL against the Open Customs Toolbox ASYCUDA / SYDONIA
  customs model — reports, lookups, reconciliations, analytics — and verify it
  privacy-preservingly. Knows the `asycuda` schema search_path, that coded
  columns are foreign keys to ref_* tables, that totals are derived (not
  stored), and the canonical join paths (declaration → item → tax line;
  manifest → bill of lading → cargo). Can test/validate generated queries via
  the customs-query-tester MCP (or a bundled script): metadata only, never row
  data — safe against databases holding real customs declarations. Use when the
  user asks for a query, report, or number from the customs / declaration /
  manifest data, or wants a query checked, tested or validated.
---

# Customs query

Turn a plain-English question about the customs data into a correct PostgreSQL
query — then **prove it runs** without exposing any row data. The model is
normalised, so two rules govern almost everything.

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

## Workflow: generate, then verify

1. **Generate.** Identify the spine and the `ref_*` joins; adapt the closest
   annotated query in **`reference/cookbook.sql`** (declaration assembly,
   items-with-taxes, cargo listing, assessed-vs-paid, revenue by HS/tax, lane
   throughput, write-off tracing, warehouse stock) rather than starting from
   scratch. Aggregate for totals; add `ORDER BY`.

2. **Verify — privacy-preservingly.** Never verify by `SELECT`-ing rows: the
   target database may hold **real customs declarations** (TINs, values,
   findings), and the user's data must not enter the conversation.

   **Preferred — the `customs-query-tester` MCP** (if its tools are available,
   possibly via ToolSearch):

   - `describe_schema` — check a table/column you are unsure of.
   - `validate_query {sql}` — EXPLAIN-only: syntax + references, no execution.
   - `test_query {sql}` — runs it read-only and time-boxed; returns **column
     names/types, row count, duration only**.

   **Fallback — the bundled script** (same guarantees through plain `psql`):

   ```bash
   bash .claude/skills/customs-query/scripts/test_query.sh "SELECT ..."
   # env/flags: CUSTOMS_DB / --db · CUSTOMS_SCHEMA / --schema (defaults: customs_sandbox / asycuda)
   ```

3. **Iterate on errors.** A failed validate/test returns the PostgreSQL error —
   fix the query, not the guardrails. If a table seems missing, check
   `describe_schema` / `Sydonia/DATA_DICTIONARY.md` before inventing columns.

4. **Deliver.** Hand the user the final query (with `SET search_path`) and
   report the verification result — e.g. *"valid; returns 42 rows, 5 columns,
   0.2 s"*. Do **not** run the query unguarded to show sample rows unless the
   user explicitly asks you to display their data.

## Privacy rules (non-negotiable)

- Verification returns **metadata only**: columns, types, row count, timing.
- Sessions are **read-only** (`default_transaction_read_only=on`) with a
  **statement timeout** — enforced by both the MCP server and the script.
- Only single `SELECT`/`WITH` statements are ever sent to be tested.
- Never bypass the tester with raw `psql -c "SELECT …"` to "peek" at data.

## Explore when unsure

```sql
SET search_path TO asycuda, public;
\d+ declaration          -- columns, types, FKs of one table
\dt                      -- all 55 tables
```

The full column reference is `Sydonia/DATA_DICTIONARY.md`; the MCP's
`describe_schema` gives the same, live.

## Pitfalls

- Forgetting the `search_path` → "relation does not exist". Set it first.
- Selecting a `*_id` and expecting a label → join the `ref_*` table.
- Summing `tax_base` instead of `tax_amount` for revenue.
- VAT cascades (its base includes duty) — don't re-derive tax; read
  `declaration_tax_line`.
- Money is `numeric(18,4)`; don't cast to float for reporting.
- `count(*)` differing from expectations on LEFT JOINs — check fan-out on the
  tax-line join before aggregating.

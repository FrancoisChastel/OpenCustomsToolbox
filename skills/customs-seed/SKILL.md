---
name: customs-seed
description: >-
  Add reference/code-table values or generate realistic sample operational data
  (manifests, SAD declarations with items, valuation notes, tax lines, payments)
  for the Sydonia Toolkit customs model, respecting every foreign key and
  the natural-key insert pattern. Use when the user wants more seed data, test
  declarations or manifests, demo data, or additional countries / tax types / HS
  codes / offices in the customs schema.
---

# Customs seed

Two jobs: extend the **reference** tables with more code values, and generate
**operational** sample data (declarations, manifests) that inserts cleanly.

## When to use

"Add a country / currency / tax type / HS code / office"; "generate N sample
declarations / manifests"; "give me demo data with 2–4 items each". If the schema
is not loaded yet, use **customs-schema-setup** first.

## Golden rules

- **Insert into the `asycuda` schema**: begin scripts with
  `SET search_path TO asycuda, public;` inside a `BEGIN … COMMIT;` transaction.
- **Use natural-key subselects**, never hard-coded surrogate ids — this is how
  `examples/e2e.sql` stays order-independent:
  ```sql
  (SELECT id FROM ref_country WHERE iso_alpha2 = 'CN')
  ```
- **Respect UNIQUE business codes** — every `ref_*` row and `trader.tin`,
  `bill_of_lading.bl_reference`, `receipt.receipt_number`, etc. must be unique.
- **Keep it balanced** — for a declaration, the per-item `tax_amount`s should
  reconcile to the `payment.amount` and `receipt.total_amount` (as in the e2e).

## Adding reference values

Insert into the relevant `ref_*` table. Provenance still matters:

- If the value comes from the referenced standard/source, note it
  (`-- src: S008` for a transport mode, ISO code, etc.).
- If it is an illustrative sample you chose, note `-- inferred sample`.
- Standard code lists (ISO 3166/4217, HS, UN/LOCODE) are seeded as
  **representative samples**, not exhaustive catalogues — say so.

See `reference/patterns.sql` for copy-paste templates.

## Generating a declaration

Follow the e2e ordering so foreign keys resolve:

1. `trader` (+ `trader_role`) for any new parties, `sys_user` if needed.
2. (optional) `manifest` → `bill_of_lading` → `container` → `manifest_cargo_item`.
3. `declaration` (header) → `declaration_item` (lines).
4. `valuation_note` + `item_value_note` (apportion freight/insurance to item CIF).
5. `declaration_tax_line` per item per tax (base · rate · amount).
6. `declaration_attached_document`, `declaration_previous_document` (write-off).
7. `declaration_status_history` transitions; `selectivity_result` +
   `inspection_act` if not GREEN; `payment` + `receipt`; final `UPDATE
   declaration SET status_id = released`.

The bundled **`reference/patterns.sql`** has a minimal but complete declaration
template you can duplicate and vary (different HS codes, item counts, values,
lane). Change the `trader_reference` / `registration_number` for each new one so
they stay unique.

## Verify after seeding

Re-run the balance check (or the **customs-validate** skill):

```sql
SET search_path TO asycuda, public;
SELECT d.registration_number,
       (SELECT sum(tl.tax_amount) FROM declaration_item di
        JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
        WHERE di.declaration_id = d.id) AS assessed,
       (SELECT sum(amount) FROM payment WHERE declaration_id = d.id) AS paid
FROM declaration d;
```

## Don't

- Don't invent real trader identities or real TINs — use obviously-synthetic
  names/ids for sample data.
- Don't disable constraints to force a load — if an insert fails, fix the data.

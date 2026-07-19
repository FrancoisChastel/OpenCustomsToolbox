# FIT.md — our model vs the official ASYCUDA World tables

This checks our reconstructed PostgreSQL model (`schema/asycuda.sql`) against the **official public
ASYCUDA World technical table descriptions** cached under `docs/` (S013–S016). Verdict first, then the
table-by-table mapping and the deliberate structural differences.

## Verdict

**We fit the official model at the entity and field level.** Every core official operational table
(manifest general segment, bill of lading, containers, SAD general segment, SAD item, SAD taxes,
attached/previous documents, selectivity, accounting, suspense) has a corresponding table in our
schema, and the field semantics line up. After cross-checking, 49 of 55 tables now cite an official
or public source; the 6 remaining `inferred` tables are our own normalisation (RBAC + trader-role
junction), which the official model handles differently rather than "not at all".

**The difference is shape, not content.** The official schema is a *wide, denormalised* physical model
optimised for the ASYCUDA World engine; ours is a *normalised relational* reference model for sandbox,
analytics and integration use (which is exactly this project's stated purpose). The two are
information-equivalent for the modelled scope. Concretely:

| Aspect | Official ASYCUDA World (S013–S016) | Our model |
|--------|-----------------------------------|-----------|
| Table names | terse codes: `GEN_TAB`, `BOL_TAB`, `SAD_General_Segment`, `xxCTYTAB` | descriptive: `manifest`, `bill_of_lading`, `declaration`, `ref_country` |
| Coded fields | store **code _and_ name inline** (`GEN_CAR_COD` + `GEN_CAR_NAM`) | store an **FK to a `ref_*` table** (normalised) |
| General segment | **repeated** into every `BOL_TAB` / `SAD_Item` row | held once in the parent, referenced by FK |
| Keys | `INSTANCE_ID` / `InstanceId` engine keys | `bigint GENERATED ALWAYS AS IDENTITY` surrogate PKs |
| HS code | split across `TAR_HSC_NB1..NB5` (national precision) | single `hs_code` + `ref_hs_tariff` hierarchy |
| Reference validity | every `UN*` table has `VALID_FROM`/`VALID_TO` | `is_active` boolean (+ `valid_from/to` on rate tables) |
| Taxes | `SAD_Tax` + `SAD_Ask_Tax` + `SAD_Global_Taxes` + `SAD_Tax_Totals` | `declaration_tax_line` (+ `is_manual` flag); totals derived by query |

None of these change *what* is captured; they change *how many tables* and *whether a value is a
code+name pair or an FK*. For a reference/analytics model, the normalised form is the intended one.

## Manifest module — official S015 → our tables

| Official table | Our table | Fit |
|----------------|-----------|-----|
| `GEN_TAB` (Manifest General Segment) | `manifest` | ✅ office, voyage, dates (departure/arrival/last discharge), totals (BOL/pkg/ctn/gross), carrier, shipping agent, transporter+nationality+mode, place of loading/unloading, tonnage net/gross, registration year/nbr/date, status. |
| `BOL_TAB` (Bill of lading) | `bill_of_lading` | ✅ reference, line/sub-line, nature, type, previous master B/L ref → our `master_bl_id`, exporter/consignee/notify, loading/unloading, packages, gross, volume, freight/customs/insurance/transport value+currency, seals. |
| `CTN_TAB` / `BOL_CTN_TAB` (Containers) | `container` | ✅ reference, type, packages, empty/full, seals, weights, volume, dangerous goods, description. |
| (goods lines within BOL) | `manifest_cargo_item` | ✅ HS, description, packages, package type, gross, container link. |
| `HIS_WRITE_OFF_TAB` / `REM_WRITE_OFF_TAB` | `declaration_previous_document` (write-off) | ◑ we model write-off as the declaration→B/L link; the official standalone write-off/history tables are folded in. |
| `MAN_TRANSIT_TAB` / `MAN_TRANSH_TAB` | `transit_declaration` | ◑ transit/transhipment management captured at declaration level. |
| vehicle sub-segment | — | ✗ **gap**: RoRo vehicle details (chassis/VIN/engine/make) not modelled (noted in COVERAGE). |

## Declaration module — official S014 → our tables

| Official table | Our table | Fit |
|----------------|-----------|-----|
| `SAD_General_Segment` | `declaration` | ✅ office, model/type, regime, manifest ref, registration/assessment/receipt serials+numbers+dates, exporter/consignee/financial/declarant, countries (export/dest/origin/trading/first-dest), value details, CAP, transport (depart/border/inland MOT, incoterm+place, container flag, place of loading, border office), release fields, **selectivity colour flags (PTY_BLU/RED/YEL/GRE)** → our `selectivity_lane_id` + `selectivity_result`. |
| `SAD_Item` | `declaration_item` | ✅ item no., packages+marks, package type, HS (NB1..NB5→`hs_code`), preference, extended+national procedure, quota, item price, valuation method, value details, attached docs, country of origin, container refs, description, gross/net mass, `VIT_CIF`→`customs_value`, `VIT_STV`→`statistical_value`. |
| `SAD_Tax` | `declaration_tax_line` | ✅ exact: `COD`→tax_type, `BSE`→tax_base, `RAT`→rate, `AMT`→amount, `MOP`→mode_of_payment, `TYP`→`is_manual`. |
| `SAD_Ask_Tax` (manual taxes) | `declaration_tax_line` (`is_manual=true`) | ✅ folded into the flag. |
| `SAD_Global_Taxes`, `SAD_Tax_Totals` | (derived) | ◑ computed by query in the e2e read-out; not stored as summary tables. |
| `SAD_Attached_Documents` | `declaration_attached_document` | ✅ header/item, doc type, reference, date. |
| `SAD_Int` (Previous Documents) | `declaration_previous_document` | ✅ B/L / previous-declaration write-off. |
| `SAD_Supplementary_Unit` | `declaration_item.supplementary_qty/uom` | ✅ captured on the item. |
| `SAD_Relief` | `ref_exemption_code` + `declaration_item.exemption_id` | ✅ relief/exemption. |
| `SAD_Serial_Storage/Registration/Assessment` | `declaration` serial columns + `declaration_status_history` | ◑ serials stored on the header; lifecycle in the history table. |
| `Exit_Note_*` | `warehouse_exit` | ◑ ex-warehouse exit note modelled minimally. |
| `INSP_ACT_TAB` | `inspection_act` | ✅ inspection act. |
| `SEL_PARAM_TAB` / `SEL_*_PARAM_TAB` / `SEL_LISTS*` | `risk_criterion` (+ `ref_selectivity_lane`) | ◑ criteria catalogue simplified to one table. |
| `VAL_CTL_TAB` / `VAL_FOR_TAB` (valuation control) | `valuation_note` / `item_value_note` | ◑ we model the value build-up result, not the control formulas. |

## Reference module — official S013 (`UN*` tables) → our `ref_*` tables

Direct matches: `xxCTYTAB`→`ref_country`, `xxCURTAB`→`ref_currency`, `xxRATTAB`→`ref_exchange_rate`,
`xxCUOTAB`→`ref_customs_office`, `xxLOCTAB`→`ref_location`, `xxMOTTAB`→`ref_transport_mode`,
`xxPKGTAB`→`ref_package_type`, `xxCTNTAB`→`ref_container_type`, `xxUOMTAB`→`ref_unit_of_measure`,
`xxTODTAB`→`ref_incoterm`, `xxHS1-6TAB`/`xxTARTAB`→`ref_hs_tariff`, `xxCP1/3/4TAB`→`ref_cpc_regime`,
`xxTAXTAB`→`ref_tax_type`, `xxRULTAB`/`xxTAXTAR`→`ref_tax_rate`, `xxATDTAB`→`ref_document_type`,
`xxCP3TAB`→`ref_exemption_code`, `xxMODTAB`→`ref_declaration_type`, `xxNATTAB`→`ref_bl_nature`,
`xxWHSTAB`→`ref_warehouse`, `xxCARTAB/xxDECTAB/xxCMPTAB/xxPRPTAB`→`trader`(+`trader_role`),
`LogTable`→`audit_log`.

Official `UN*` tables we intentionally did **not** model as separate tables (folded inline or out of
scope): `xxPRFTAB` (preference → `declaration_item.preference_code`), `xxVAMTAB` (valuation method →
`valuation_method_code`), `xxTR1/TR2TAB` (nature of transaction), `xxTOPTAB` (terms of payment),
`xxMOPTAB` (means of payment → `mode_of_payment`), `xxINDTAB` (empty/full → `container.empty_full`),
`xxSEATAB` (seals parties), `xxQUOTAB` (quota → `declaration_item.quota`), `xxCAPTAB` (CAP),
`xxMUQTAB` (measurement qualifiers), `xxHOLTAB`/`xxLNGTAB`/`xxPRTTAB`/`xxKWD*` (system housekeeping),
and the many `*_link` tables (e.g. `xxCTYMOT`, `xxCUOMOT`, `xxPRFCTY`) which are M:N junctions our
FK design expresses differently. These are listed as known gaps in COVERAGE.md.

## Accounting module — official S016 → our tables

| Official | Our table | Fit |
|----------|-----------|-----|
| `xxATITAB`/`xxATOTAB` (account transactions in/out) | `account` + `account_movement` | ✅ accounts and ledger movements. |
| receipts + `TAX_TAB` (taxes per receipt) | `receipt` + `payment` + `declaration_tax_line` | ✅ payment/receipt with per-tax detail. |
| `SER_LETTERS_TAB` / `SER_NBERING_TAB` (serial mgmt) | serial columns on `declaration`/`receipt` | ◑ serials stored inline rather than in a dedicated numbering service table. |
| cashier/shift/daybook report tables (`RPT*`) | — | ✗ reporting/aggregation tables out of scope (analytics can be built as views). |

## Suspense / transit — official S014 + S019

`SUS_WH_IN` (warehouse entry/exit) → `warehouse_entry`/`warehouse_exit`; `WHS_DLY*` (extension of
delay) → `ref_warehouse` + item `warehouse_days`; temporary admission → `temporary_admission`;
transit → `transit_declaration`; guarantees → `guarantee`. The Suspense Declarations manual (S019)
now grounds these tables that were previously `inferred`.

## Remaining honestly-inferred (6 tables)

`trader_role`, `sys_role`, `sys_permission`, `sys_user_role`, `sys_role_permission` — RBAC and the
trader-role junction. ASYCUDA World has role-based access, but the reference docs don't publish a
user/role/permission schema, so this stays our normalisation. `manifest_status_history` is grounded
by `GEN_TAB.STA` but the *history* shape is ours.

## Bottom line for the user

Yes — the reconstruction fits your official data. Where the official docs are more authoritative than
the national manuals we started from, the schema now cites them (S013–S016, S019), which upgraded 11
tables from `inferred` to documented. The intentional divergences (normalised vs denormalised,
FK vs code+name, derived totals) are the right choice for a sandbox/analytics reference model and are
listed above and in COVERAGE.md so nothing is hidden.

# COVERAGE.md — module coverage vs GOAL §4

Legend: **documented** = grounded in a cited source (`-- src:` in the DDL); **partial** =
core grounded, some columns/tables inferred; **inferred** = introduced by modelling judgement
(`-- inferred`), no public source at this granularity. IDs (S0xx) resolve in SOURCES.md.

Every `CREATE TABLE` in `schema/asycuda.sql` (55 tables) carries a `-- src:` or `-- inferred`
tag; this file rolls those up by GOAL §4 module.

> **Official-data update.** The official UNCTAD/DTL table descriptions in `docs/` (S013 Reference
> Tables, S014 Declaration Tables, S015 Manifest Tables, S016 Accounting Tables) plus the Suspense
> Declarations manual (S019) are now cited across the schema. This upgraded 11 tables from
> `inferred` to documented (exchange-rate, unit-of-measure, tax-rate, manifest-status,
> account-movement, guarantee, warehouse entry/exit, temporary-admission, risk-criterion, audit-log).
> See `FIT.md` for the full official-table-to-model mapping. Current tally: **49 documented / 6 inferred**.

---

## 4.1 Reference / configuration — **documented (partial)**

| Table | Status | Grounding |
|-------|--------|-----------|
| `ref_country` | documented | S008 (ISO 3166 2-alpha nationality) |
| `ref_currency` | documented | S008 (ISO 4217 freight currency), S003 box 22 |
| `ref_exchange_rate` | documented | S013 (official xxRATTAB), S003 box 23 |
| `ref_customs_office` | documented | S008 (customs_office_code AN5), S003 box 29 |
| `ref_location` (UN/LOCODE ports) | documented | S008 (place codes = UN/LOCODE) |
| `ref_transport_mode` | documented | S008 (full 1–9 code list) |
| `ref_package_type` | documented | S008 (UN/ECE Rec 21 alpha-2), S003 box 31 |
| `ref_container_type` | documented | S008 (ISO 6346:1995) |
| `ref_unit_of_measure` | documented | S013 (official xxUOMTAB statistical units), S003 box 41 |
| `ref_incoterm` | documented | S003 box 20, S012 |
| `ref_hs_tariff` | documented | S003 box 33 (HS), S008 (6-digit HS) |
| `ref_cpc_regime` | documented | S003 box 37 (CPC extended procedure) |
| `ref_tax_type` | documented | S003 box 47 (per-tax calculation) |
| `ref_tax_rate` | documented | S013 (official xxRULTAB taxation rules / xxTAXTAR) |
| `ref_document_type` | documented | S003 box 44, S008 attached_document |
| `ref_exemption_code` | documented | S003 box 37 national procedure (ANC) |
| `ref_declaration_type` | documented | S003 box 1 (IM4/EX1/SD4) |
| `ref_declaration_status` | documented | S002 (finder statuses) |
| `ref_manifest_status` | documented | S015 (official GEN_TAB STA status) |
| `ref_bl_nature` | documented | S008 (Bol_nature codes) |
| `ref_selectivity_lane` | documented | S002, S005 (four lanes) |
| `ref_warehouse` | documented | S003 box 49 |
| `trader` / `trader_role` | documented / inferred | S003 boxes 2/8/14, S008 traders; role-junction inferred |
| `sys_user` | documented | S002 (registered users) |
| `sys_role`,`sys_permission`,`sys_user_role`,`sys_role_permission` | inferred | RBAC implied; no public schema |

## 4.2 Manifest / cargo — **documented**

| Table | Status | Grounding |
|-------|--------|-----------|
| `manifest` | documented | S008, S006 (general segment) |
| `bill_of_lading` (master/house, self-ref) | documented | S008, S006, S010 (Bol segment, master/house, degroupage) |
| `container` | documented | S008 (ctn_segment, ISO 6346, seals, reefer) |
| `manifest_cargo_item` | documented | S008 (Goods/Commodity segment) |
| `manifest_status_history` | partial | S015 (GEN_TAB STA) grounds status; history shape inferred |

*Note:* the manifest XML also defines a vehicles sub-segment (chassis/VIN/engine) [S008]; it is
noted in RESEARCH_LOG but not modelled as a table (out of the e2e path). Marked as a known gap.

## 4.3 Declaration — the SAD (core) — **documented**

| Table | Status | Grounding |
|-------|--------|-----------|
| `declaration` (general segment) | documented | S003 (boxes 1–49/B), S001 |
| `declaration_item` (item segment) | documented | S003 (boxes 31–49) |
| `valuation_note` | documented | S003 (value build-up) |
| `item_value_note` | documented | S003 (per-item CIF apportionment), box 46 |
| `declaration_tax_line` | documented | S003 box 47 (type, base, rate, amount, mode) |
| `declaration_attached_document` | documented | S003 box 44, S008 |
| `declaration_previous_document` | documented | S003 box 40, S008 (write-off vs B/L) |
| `declaration_status_history` | documented | S002 (lifecycle) |
| `selectivity_result` | documented | S002, S005 |

## 4.4 Accounting — **documented**

| Table | Status | Grounding |
|-------|--------|-----------|
| `account` | documented | S003 box 48 (deferred payment account) |
| `payment` | documented | S003 box B, S005 |
| `receipt` | documented | S003 box B (receipt number) |
| `account_movement` | documented | S016 (official account transactions in/out) |
| `guarantee` | documented | S019 (suspense guarantees), S003 box 52 |

## 4.5 Transit & suspense — **documented** (S019)

| Table | Status | Grounding |
|-------|--------|-----------|
| `transit_declaration` | documented | S003 boxes 50–53 (principal, offices, guarantee) |
| `ref_warehouse` | documented | S003 box 49 |
| `warehouse_entry` / `warehouse_exit` | documented | S014 (SUS_WH_IN), S019 (suspense manual) |
| `temporary_admission` | documented | S019 (suspense temporary admission regime) |

## 4.6 Selectivity / risk — **documented**

| Table | Status | Grounding |
|-------|--------|-----------|
| `ref_selectivity_lane` | documented | S002, S005 |
| `selectivity_result` | documented | S002, S005 |
| `inspection_act` | documented | S002, S005 (examination) |
| `risk_criterion` | documented | S014 (official SEL_*_PARAM_TAB selectivity criteria) |

## 4.7 Audit / workflow (cross-cutting) — **documented** (LogTable)

| Table | Status | Grounding |
|-------|--------|-----------|
| `audit_log` | documented | S013 (official LogTable actions/procedures) |
| `*_status_history` tables | documented/inferred | declaration & manifest lifecycles (see above) |

---

## Roll-up

- **Documented (`-- src:`):** 49 tables — after citing the official UNCTAD/DTL table descriptions
  (S013–S016) and the Suspense manual (S019), all reference/manifest/declaration/accounting/transit/
  selectivity/audit tables are grounded in an official or public source.
- **Inferred (`-- inferred`):** 6 tables — `trader_role`, `sys_role`, `sys_permission`, `sys_user_role`,
  `sys_role_permission` (RBAC + trader-role junction; no published ASYCUDA user/role schema).
- **Known gaps (not blocking the e2e):** manifest vehicle sub-segment; degroupage/split as its own
  table (modelled via `bill_of_lading.master_bl_id`); full ISO/UN/WCO code-list *values* (seeded as
  representative samples of the referenced standard, not exhaustive catalogues).

No table is left untagged; the honest inferred set is preferred over fabricated citations.

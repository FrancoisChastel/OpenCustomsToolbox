# GOAL.md — Reconstruct the SYDONIA / ASYCUDA World data model in PostgreSQL

Mission: build a faithful **reference data model** of ASYCUDA World (SYDONIA) — the UNCTAD customs
management system — by deep-researching *public* documentation, then produce a runnable
**PostgreSQL** schema plus a data dictionary. This is a functional/reference reconstruction for
sandbox, integration, analytics, or training use — not an attempt to obtain UNCTAD's proprietary
internal schema. Drive this with Claude Code's `/goal`; work autonomously and do not ask for input.

---

## 1. Done conditions (verify each yourself by running the check, not by assertion)

You are finished only when ALL of these hold and you have re-run the checks this session:

1. **Schema loads clean.** Running `schema/asycuda.sql`, then `schema/seed_reference.sql`, against a
   fresh PostgreSQL 15+ database (`createdb` + `psql -v ON_ERROR_STOP=1 -f …`) completes with zero
   errors. An end-to-end example (`examples/e2e.sql`: manifest → declaration with 2 items →
   valuation note → tax lines → release) inserts cleanly with referential integrity intact.
   *Check: actually run it and read the output.*
2. **Every table is grounded.** `grep -niE 'create[ \t]+table' schema/*.sql` and confirm every
   `CREATE TABLE` is annotated with either `-- src: <ID>` (an ID present in `SOURCES.md`) or
   `-- inferred`. Zero tables may have neither. *Check: grep and eyeball the annotations.*
3. **Every source is cited and cached.** Each cited `<ID>` appears in `SOURCES.md` (ID, URL, one-line
   note) and has a saved local copy under `sources/`. Every ID used in the schema resolves to such an
   entry. *Check: grep the IDs out of the schema and confirm each has a row and a file.*
4. **Supporting docs exist and match the schema:** `DATA_DICTIONARY.md` (every table/column: purpose,
   type, nullability, source), `ERD.md` (a Mermaid ER diagram), `COVERAGE.md` (every module in §4
   marked documented / partial / inferred), `RESEARCH_LOG.md` (append-only findings with source IDs).
5. Before declaring the goal met, **re-run the load in condition 1 and the grep in condition 2** and
   confirm both pass. `STATE/progress.md` records progress and, on the final line, `STATUS: COMPLETE`
   — set only once 1–4 truly hold.

If something cannot be sourced from a document you fetched, tag it `-- inferred` and mark it in
`COVERAGE.md` rather than inventing a citation. A larger honest inferred set beats a fabricated
"documented" one.

---

## 2. Scope & source policy (non-negotiable)

**Use freely (public):** UNCTAD/official ASYCUDA material (`asycuda.org`, esp. its Data Model and
DAU/SAD pages); the **WCO Data Model v3** it aligns to; the **SAD** (Single Administrative Document)
structure; national customs administrations that publish full ASYCUDA World manuals (e.g. Uganda
URA, Grenada, Federated States of Micronesia, Marshall Islands); academic theses/papers on ASYCUDA
implementations; public trader XML/EDI integration guides; ISO/UN/WCO code lists.

**Never (stop and log under "Skipped — out of scope" if a task implies these):** downloading,
cracking, or decompiling the ASYCUDA software to dump its internal schema; probing, scanning, or
logging into any live national customs deployment beyond fetching its openly published docs; using
leaked credentials or bypassing access controls; reproducing long verbatim copyrighted text (extract
structure and field semantics, then restate in your own words; quote only short field labels, cited).

The public corpus is more than sufficient — you will not need "shady" sources.

---

## 3. How to work (evidence-first loop)

Each cycle: read `GOAL.md`, `STATE/progress.md`, `RESEARCH_LOG.md`, `COVERAGE.md`, and current
`schema/*.sql`; pick the single highest-value next task; do it; update state.

**Evidence-first ordering (critical):** never write DDL for a table/column until a source for it is
already in `SOURCES.md` *and* the document is cached under `sources/`. Order is always:
*fetch → save under sources/ → capture a short cited snippet in `RESEARCH_LOG.md` → restate → model.*
Anything you introduce by your own reasoning must be tagged `-- inferred` in the DDL and marked
`inferred` in `COVERAGE.md` — never dressed up as documented. Prefer appending over deleting
findings. If two sources conflict, record both and prefer WCO/official alignment, noting the choice.

---

## 4. Seed domain model (validate & flesh out — don't start from zero)

Treat each entry as a table family to confirm and detail against sources. Names are suggestions;
every table and important field must end up cited in `DATA_DICTIONARY.md` or flagged `inferred`.

**4.1 Reference / configuration (backbone; mostly code tables):** `ref_country` (ISO 3166),
`ref_currency` + `ref_exchange_rate`, `ref_customs_office`, `ref_hs_tariff` (commodity codes,
hierarchy, duty/tax links), `ref_tax_type` + `ref_tax_rate`, `ref_cpc_regime` (customs procedure
codes/regimes), `ref_package_type`, `ref_transport_mode`, `ref_unit_of_measure`, `ref_incoterm`,
`ref_document_type`, `ref_exemption_code`, `ref_warehouse`, `trader`/`economic_operator`
(TIN, role: importer/exporter/broker/carrier), `sys_user`/`sys_role`/`sys_permission`.

**4.2 Manifest / cargo:** `manifest` (carrier, vessel/flight, ports, dates, office),
`bill_of_lading_master` and `bill_of_lading_house` (house B/L = a consignment), `container`,
`manifest_cargo_item`, `manifest_status_history` (document lifecycle).

**4.3 Declaration — the SAD (core):** general segment (whole consignment) + repeating item segments.
`declaration` (declarant/broker, exporter, consignee, importer, office, regime, type, trader ref,
dates, dispatch/destination, transport, invoice value+currency, freight, insurance, totals, status,
selectivity lane); `declaration_item` (line no., HS code, description, origin, gross/net mass,
packages, statistical value, customs/CIF value, procedure, preference, quota); `valuation_note` +
`item_value_note` (freight/insurance apportioned to per-item CIF, the tax base);
`declaration_tax_line` (per item per tax: base, rate, amount); `declaration_attached_document`
(invoice, license, permit, certificate); `declaration_previous_document` (links items to manifest
B/L); `declaration_status_history` (stored → registered → assessed → paid → released);
`selectivity_result` (green/yellow/red/blue lane, inspection, risk criteria).

**4.4 Accounting:** `receipt`, `payment`, `account`, `account_movement`, `guarantee`/`security`.

**4.5 Transit & suspense:** `transit_declaration` (departure/destination office, itinerary,
guarantee), `warehouse_entry`/`warehouse_exit`, `temporary_admission`.

**4.6 Selectivity / risk:** `risk_criterion`, `selectivity_lane`, `inspection_act`.

**4.7 Audit / workflow (cross-cutting):** `document_event`/`audit_log` (who/what/when, status
transitions).

---

## 5. Phases

0. **Bootstrap** — create `STATE/progress.md`, `RESEARCH_LOG.md`, `SOURCES.md`, `COVERAGE.md`,
   `DATA_DICTIONARY.md`, `ERD.md`, the `sources/` folder, and an empty `schema/asycuda.sql`. Copy §4
   into `COVERAGE.md` as an unchecked checklist. Write the Phase 1 task list.
1. **Orient** — fetch/cache and digest `asycuda.org` (Data Model, DAU/SAD), WCO Data Model v3
   overview, and the SAD general/item segment structure. Capture the module list and field taxonomy.
2. **Mine national manuals (highest yield)** — fetch/cache several national ASYCUDA World
   declaration/manifest/valuation guides; extract field names, code lists, segments, lifecycles;
   restate with citations; cross-check against §4 and each other.
3. **Fill code tables & standards** — pin down §4.1 reference tables using ISO/UN/WCO code lists and
   the tariff/tax structure; choose types and `CHECK` constraints.
4. **Draft the schema, module by module** — reference/config → traders/users → manifest → declaration
   (header, item, valuation, tax lines, attached/previous docs, status) → accounting → transit/
   suspense → selectivity → audit. Load into a scratch DB after each module; fix before proceeding.
5. **Seed + validate** — write `schema/seed_reference.sql` and `examples/e2e.sql`; prove the
   end-to-end example inserts cleanly.
6. **Document & finalize** — complete `DATA_DICTIONARY.md`, `ERD.md`, `COVERAGE.md`; re-run the
   Done-condition checks in §1; set `STATUS: COMPLETE`.

---

## 6. PostgreSQL conventions

Postgres 15+; `snake_case`; `ref_`/`sys_` prefixes. Surrogate PKs
`bigint GENERATED ALWAYS AS IDENTITY`, keeping real business codes (HS, office, TIN) as
`UNIQUE NOT NULL`. Money `numeric(18,4)`; mass/qty `numeric(18,3)`; codes sized `varchar`; dates
`date`/`timestamptz`; real `boolean`. Coded columns get a FK to their `ref_*` table or a small
`CHECK (... IN (...))`. Model status lifecycles as `ref_*_status` + a `*_status_history` child.
`COMMENT ON` anything non-obvious. One `schema/asycuda.sql` that runs top-to-bottom (or a `schema/`
folder + `run_all.sql` that `\i`-includes in dependency order); it must run in one command.

**Provenance annotation (satisfies Done-condition 2):** put a `-- src: <ID>` or `-- inferred`
comment on each `CREATE TABLE` (the table-level tag covers its columns; tag individually-inferred
columns too). Example:

```sql
-- src: S002, S005   (Uganda URA declaration manual; FSM declaration guide)
CREATE TABLE declaration ( ... );
```

# RESEARCH_LOG.md — append-only findings (evidence-first)

Each entry: `[Sxxx] finding → how it maps to the schema`. Short quoted labels only; semantics restated.

---

## 2026-07-16 — Orientation (Phase 1)

**[S001] SAD = the declaration form.** The SAD breaks down into 54 boxes; the full version comes in
8 parts. The WCO treats the SAD as the international-standard customs declaration. Import parts are
6/7/8, export 2/3, transit 1/4/5. → the `declaration` (general segment) + `declaration_item`
(repeating item segment) split is the core of the model.

**[S003] SAD general vs item segment.** "The SAD main form consists of two segments: the general
segment covering ... the whole consignment ... and the item segment containing information needed
to clear the consignment at each item level (commodity code, value, country of origin, etc.)."
→ header/item table split confirmed and grounded.

**[S009] WCO Data Model alignment.** WCO DM v3 primary classes: Declaration → GoodsShipment →
Consignment; GoodsShipment is the base for the import/export declaration; Consignment describes the
transport between consignor and consignee. → validates header(consignment/transport) + item(goods
shipment) + valuation structure; used to name/organise, not to invent fields.

---

## 2026-07-16 — Declaration module (SAD box map, Phase 2/4)

**[S003] Header boxes (general segment):**
- Box 1 Declaration type code (e.g. `EX1`, `IM4`, `SD4`). → `declaration.declaration_type`.
- Box 2 Exporter code + name/address. → `declaration.exporter_*`.
- Box 5 Items = total number of declared items; Box 6 No. packages (whole declaration).
- Box 7 Reference number = "Unique reference number of a declaration provided by the trader." → `trader_reference`.
- Box 8 Consignee code (TIN/Business ID) + name; Box 9 Financial (party paying duties).
- Box 10 Country last consignment; Box 11 Trading country; Box 12 Value details (from valuation note).
- Box 14 Declarant code+name (broker/agent or trader); Box 15 Country of export; Box 17 Country of destination.
- Box 18/21 Identity & nationality of active means of transport (departure / crossing border).
- Box 19 Ctr = container indicator ("Ticking this box will cause a container list to be opened").
- Box 20 Delivery terms = INCOTERMS code + place [S012]; Box 22 Currency + total invoiced amount.
- Box 23 Exchange rate (invoice currency → national); Box 25 Mode of transport at border; Box 26 Inland mode.
- Box 27 Place of discharge; Box 29 Office of entry; Box 30 Location of goods.
→ `declaration` header columns.

**[S003] Item boxes (item segment), boxes 31–49:**
- Box 31 Packages & description: marks1/marks2, number of packages, kind-of-packages code+name, container no., goods description.
- Box 32 Item number (system-assigned line no.); Box 33 Commodity code (HS); Box 34 Country of origin code.
- Box 35 Gross mass (incl. packaging); Box 38 Net mass (excl. packaging).
- Box 36 Preference code; Box 37 CPC (4-digit extended procedure = requested 2 + previous 2) + national procedure (ANC 3-char).
- Box 39 Quota; Box 40 Summary/previous document (B/L or AWB, or previous declaration under some CPCs).
- Box 41 Supplementary units; Box 42 Item price; Box 43 Valuation method code; Box 44 Additional information/attached docs.
- Box 45 Adjustment; Box 46 Statistical value = "Customs value ... used in the tax rules as the tax base."
- Box 47 Calculation of taxes = per item, per tax: "tax type; tax base; tax rate, the tax amount ... and the mode of payment. Eight taxes can be displayed on one declaration."
- Box 48 Deferred payment (account no.); Box 49 Warehouse identification + time delay (suspense regimes).
→ `declaration_item`, `declaration_tax_line`, `declaration_attached_document`, `declaration_previous_document`.

**[S003] Valuation note.** "input of value build up information such as freight and insurance costs":
external freight, internal freight, insurance → apportioned to each item to produce item CIF /
customs value, which is the tax base (box 46). → `valuation_note` (header) + `item_value_note` (per item).

**[S003] Assessment / accounting (box B).** "mode of payment, the assessment number and receipt
number when a declaration has been paid ... sum of all amounts to be paid." → `receipt`, `payment`,
`account`, `declaration.assessment_*`.

---

## 2026-07-16 — Declaration lifecycle & selectivity (Phase 2)

**[S002] Status lifecycle.** Declarations are searched by "document status such as a 'registered'
status" and can be stored, registered, assessed/validated, paid, released; the finder retrieves
"stored", "unpaid", etc. → `ref_declaration_status` + `declaration_status_history`
(stored → registered → assessed → paid → released; plus queried/cancelled).

**[S002][S005] Selectivity = four lanes.** "The system has four selectivity lanes": **Green**, **Yellow**,
**Red**, **Blue**. Green = release (customs reserves right to examine); Red/Yellow require
examination; Blue = post-clearance audit. "Release Order (selectivity)" issued on green/blue.
→ `ref_selectivity_lane` + `selectivity_result` (+ `inspection_act`, `risk_criterion`).

---

## 2026-07-16 — Manifest module (Phase 2)

**[S008] Manifest = general segment + B/L segments.** AWMDS "consists of two big data segments: the
general segment of the manifest `<General_segment>` and detailed data for each transport document
`<Bol_segment>`." → `manifest` + `bill_of_lading` (with master/house distinction).

**[S008] General segment fields:** customs office code, voyage/flight number, date/time of departure
& arrival, date of last discharge; totals (number of B/Ls, packages, containers, vehicles, gross
mass); transport information (mode of transport code, identity/nationality of transporter,
registration/IMO/IATA, master name); carrier (code/name/address); shipping agent; load/unload place
(place of departure/destination, UN/LOCODE); tonnage (net/gross). → `manifest` columns.

**[S008] Mode of transport code list:** "1=Sea; 2=Rail; 3=Road; 4=Air; 5=Postal; 6=Multimodal;
7=Fixed; 8=Inland waterways; 9=Unknown." → `ref_transport_mode` seed.

**[S008] B/L segment fields:** Bol_reference, line_number, Bol_nature ("22=Exports; 23=Imports;
24=In-Transit; 26=Freight remaining on board (FROB); 28=Transhipment"), Bol_type_code,
master_bol_ref_number (consolidated cargo); traders (exporter, notify, consignee — code/name/address);
container segment (reference per ISO 6346, packages, size-type, empty/full, seals, weights, reefer
temp/humidity, UNDG dangerous goods, HS, volume); vehicles (chassis/VIN, engine, make, year);
goods (packages, package type UN/ECE Rec 21 alpha-2, gross mass, marks, description, origin/dest,
volume, HS code); value segment (freight PP/CC + value + currency, customs value, insurance,
transport). → `bill_of_lading`, `container`, `manifest_cargo_item`.

**[S006][S010][S011] Master vs house B/L / degroupage.** A master B/L carries the consolidator's
consignee code and is broken down ("degroupage") into house B/Ls, each a consignment. → self-referential
`bill_of_lading.master_bl_id`, and B/L nature distinguishing master/house.

---

## 2026-07-16 — Reference / standards (Phase 3)

- **[S008]** Ports = UN/LOCODE; container size-type = ISO 6346:1995; package type = UN/ECE CEFACT
  Recommendation 21 (alpha-2); transporter nationality = ISO 3166 2-alpha; freight currency = ISO 4217;
  dangerous goods = UNDG. → `ref_customs_office`/port, `ref_container_type` (inferred table), `ref_package_type`, `ref_country`, `ref_currency`.
- **[S003]** Commodity = HS (Harmonized System); delivery terms = INCOTERMS [S012]; CPC 4-digit procedure.
  → `ref_hs_tariff`, `ref_incoterm`, `ref_cpc_regime`.
- **[S003]** Box 47 tax calculation implies a tax-type catalogue and rates. → `ref_tax_type`, `ref_tax_rate`.

Anything below the granularity of these documents (surrogate keys, audit columns, some code-table
column choices, unit-of-measure catalogue, guarantee/security tables, exchange-rate table shape) is
introduced by modelling judgement and is tagged `-- inferred` in the DDL and `inferred` in COVERAGE.md.

---

## 2026-07-16 — Official public table descriptions added (docs/)

The **official public ASYCUDA World technical table descriptions** were cached in
`docs/` and cited as S013–S016 (+ S017–S020 official manuals). These describe the real physical schema.

**[S015] Manifest.** `GEN_TAB` (general segment) and `BOL_TAB` (bill of lading, with the general
segment **denormalised** into each B/L row), `CTN_TAB`/`BOL_CTN_TAB` (containers), write-off and
transit/transhipment management tables. Confirms `manifest`/`bill_of_lading`/`container`/
`manifest_cargo_item`. `BOL.PRV` (previous master B/L ref) confirms our `master_bl_id`.

**[S014] Declaration.** `SAD_General_Segment` (selectivity as four colour flags PTY_BLU/RED/YEL/GRE +
query flag; RLS_* release fields; IDE_REG/AST/RCP serials), `SAD_Item` (HS split NB1..NB5, VIT_CIF,
VIT_STV = statistical value/tax base), `SAD_Tax` (COD/BSE/RAT/AMT/MOP/TYP → exact match to
`declaration_tax_line`, incl. new `is_manual` for TYP), `SAD_Attached_Documents`, `SAD_Int` (previous
docs), `SAD_Relief`, `SUS_WH_IN` (warehouse), `INSP_ACT_TAB`, `SEL_*_PARAM_TAB`, `VAL_CTL_TAB`.

**[S013] Reference.** ~80 `UN*` tables. Direct matches for every `ref_*` we built; all carry
`VALID_FROM`/`VALID_TO` (we use `is_active` + rate validity). `LogTable` → `audit_log`.

**[S016] Accounting.** Account transactions in/out, receipts + `TAX_TAB`, serial management → our
`account`/`account_movement`/`payment`/`receipt`.

**[S019] Suspense.** Warehousing, transit, temporary admission, guarantees, extension of delay —
grounds the previously-inferred suspense tables.

**Outcome:** schema re-tagged to cite official sources; 11 tables upgraded inferred→documented
(now 49 documented / 6 inferred). Full mapping and structural-difference analysis in `FIT.md`.

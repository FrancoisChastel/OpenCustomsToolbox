---
title: XML messages & the wire format
description: How ASYCUDA World serialises declarations and manifests as XML e-documents — the SAD→XML→schema field map, the AWMDS cargo stream, and the spec-vs-reality wire-format trap.
tags:
  - platform
---

# XML messages & the wire format

In ASYCUDA World (v4) every business object — a declaration, a cargo manifest —
is an **XML e-document**. The Java client's *Export XML File* / *Import XML File*
buttons round-trip these files, and XML is the lingua franca between AW and any
system that speaks the WCO Data Model.

That matters here for one reason: **UNCTAD does not publish ASYCUDA's physical
database schema.** The field-level model is public *only through the XML layer*
(plus national customs manuals). So the XML is the one public window into the
same fields this toolbox reconstructs as PostgreSQL tables — which is why the
three-way map below (SAD box → AW XML tag → our column) is the core of this page.

!!! warning "Spec vs. reality — the wire-format trap"
    The idealised UNCTAD spec (*"SAD XML Message Description"*) documents a tree
    rooted at `<Sad>` / `<Items>` / `<Tariff>`. **Real exported/imported AW
    instances use a different root and naming** — verified identical across the
    official `Asycuda421.xsd`, national sample XMLs, and six independent
    integrator codebases:

    - Root element is **`<ASYCUDA>`** (not `<Sad>`).
    - Adds top-level `<Export_release>`, `<Assessment_notice>`, `<Global_taxes>`,
      and **`<Property>`** (holding `Sad_flow` I/E, `<Forms>`, `<Nbers>`,
      `Place_of_declaration`, `Date_of_declaration`).
    - The item tariff block is **`<Tarification>`** (not `<Tariff>`).
    - `<Identification>` carries `<Registration>`, `<Assessment>`, `<receipt>`
      (each with `Serial_number` / `Number` / `Date`).

    **Practical rule:** use the **spec PDF for field semantics/formats** and a
    **real sample for exact structure**. Target the `<ASYCUDA>`-rooted format.
    The most complete public XSD is `Asycuda421.xsd` (GitHub
    `Alphaquest2005/MRManager`); real samples include `sc001cs/AsycudaXML` and
    the St. Kitts & Nevis sample XMLs (`SAD_EXAMPLE.XML` / `SADDEC.XML`).

Every declaration has **two segments**: a **general segment** (consignment-level
— parties, transport, valuation totals) and repeating **item segments** (one per
commodity — HS code, origin, value, quantity, taxes). Both map cleanly onto our
[`declaration`](../schema/declaration.md) and `declaration_item` tables.

## The three-way field map

Columns: **SAD box** · **field** · **AW XML tag** (spec naming) · **Open Customs
Toolbox column** in the [`asycuda`](../schema/data-dictionary.md) schema. Where
our reconstruction has no counterpart, the cell reads **—**.

### General segment (consignment level)

| SAD box | Field | AW XML tag | Toolbox column |
|:-------:|-------|------------|----------------|
| A | Customs office | `Identification/Office_segment/Customs_clearance_office_code` | `declaration.office_id` |
| A | Registration identity | `Identification/Registration` (Serial/Number/Date) | `declaration.registration_serial` · `registration_number` · `registration_date` |
| 1 | Declaration type / procedure | `Identification/Type/Type_of_declaration`, `General_procedure_code` | `declaration.declaration_type_id` |
| 2 | Exporter / consignor | `Traders/Exporter/Exporter_code`, `Exporter_name` | `declaration.exporter_id` |
| 3 | Forms (X of Y) | — | — |
| 5 | Total items | (count of `<Item>`) | `declaration.total_items` |
| 6 | Total packages | `Identification/Total_number_of_packages` | `declaration.total_packages` |
| 7 | Declarant reference (LRN/UCR) | `Declarant/Reference/Number` | `declaration.trader_reference` |
| 8 | Importer / consignee | `Traders/Consignee/Consignee_code`, `Consignee_name` | `declaration.consignee_id` |
| 9 | Financial-settlement party | `Traders/Financial/Financial_code` | `declaration.financial_id` |
| 10 | Country of last consignment | `General_information/Country/...` | `declaration.country_last_consign_id` |
| 11 | Trading country | `General_information/Country/Trading_country` | `declaration.trading_country_id` |
| 12 | Value details | `General_information/Value_details` | — |
| 14 | Declarant / representative | `Declarant/Declarant_code`, `Declarant_representative` | `declaration.declarant_id` |
| 15 | Country of dispatch/export | `General_information/Country/Export/Export_country_code` | `declaration.country_export_id` |
| 16 | Country of origin (header) | `General_information/Country/...` | `declaration.country_origin_id` |
| 17 | Country of destination | `General_information/Country/Destination/Destination_country_code` | `declaration.country_destination_id` |
| 18 | Transport identity & nationality (dep/arr) | `Transport/Means_of_transport/Departure_arrival_information/Identity`, `Nationality` | `declaration.border_transport_identity` |
| 19 | Container flag (0/1) | `Transport/Container_flag` | — |
| 20 | Delivery terms (INCOTERMS) | `Transport/Delivery_terms/Code`, `Place` | `declaration.incoterm_id` · `delivery_place` |
| 21 | Border transport identity & nationality | `Transport/Means_of_transport/Border_information/Identity`, `Nationality` | `declaration.border_transport_identity` |
| 22 | Currency & total invoiced | `Valuation/Invoice/Currency_code`, `Amount_foreign_currency` | `declaration.currency_id` · `total_invoice_amount` |
| 23 | Exchange rate (system-filled) | `Currency_rate` | `declaration.exchange_rate` |
| 24 | Nature of transaction | `Financial/Financial_transaction/Code_1`, `Code_2` | — |
| 25 | Border mode of transport | `Transport/.../Border_information/Mode` | `declaration.transport_mode_border_id` |
| 26 | Inland mode | `Transport/.../Inland_mode_of_transport` | `declaration.transport_mode_inland_id` |
| 27 | Place of loading/unloading | `Transport/Place_of_loading/Code`, `Name` | `declaration.place_of_discharge_id` |
| 28 | Financial & banking data | `Financial/Bank`, `Financial/Terms` | — |
| 29 | Office of entry/exit | `Transport/Border_office/Code` | `declaration.office_id` |
| 30 | Location of goods | `Transport/Location_of_goods` | — |
| B | Accounting (assessment) | `Identification/Assessment` (Serial/Number/Date) | `declaration.assessment_number` · `assessment_date` |

### Item segment (per commodity, repeats)

| SAD box | Field | AW XML tag | Toolbox column |
|:-------:|-------|------------|----------------|
| 31 | Packages & goods description | `Packages/Number_of_packages`, `Marks1/2_of_packages`, `Kind_of_packages_code` | `declaration_item.number_of_packages` · `package_type_id` · `marks_and_numbers` · `goods_description` |
| 32 | Item number | (position of `<Item>`) | `declaration_item.item_number` |
| 33 | Commodity code (HS) | `Tariff/Harmonized_system/Commodity_code`, `Precision_1..4` | `declaration_item.hs_id` · `hs_code` |
| 34 | Country of origin | `Goods_description/Country_of_origin_code` | `declaration_item.country_origin_id` |
| 35 | Gross mass (kg) | `Valuation_item/Weight/Gross_weight_itm` | `declaration_item.gross_mass` |
| 36 | Preference code | `Tariff/Preference_code` | `declaration_item.preference_code` |
| 37 | Procedure (CPC: extended + national) | `Tariff/Extended_customs_procedure`, `National_customs_procedure` | `declaration_item.cpc_id` · `national_procedure` |
| 38 | Net mass (kg) | `Valuation_item/Weight/Net_weight_itm` | `declaration_item.net_mass` |
| 39 | Quota | `Tariff/Quota/Quota_code` | `declaration_item.quota` |
| 40 | Previous document / summary declaration | `Previous_document/Summary_declaration`, `Previous_document_reference` | `declaration_previous_document.reference` (+ `bl_id` / `prev_declaration_id`) |
| 41 | Supplementary units | `Tariff/Supplementary_unit/Supplementary_unit_quantity`, `_code` | `declaration_item.supplementary_qty` · `supplementary_uom_id` |
| 42 | Item price | `Valuation_item/Invoice/Amount_foreign_currency`, `Currency_code` | `declaration_item.item_price` |
| 43 | Valuation method (WTO 1–6) | `Tariff/Valuation_method_code` | `declaration_item.valuation_method_code` |
| 44 | Additional info / documents | `Attached_documents/Attached_document`, `Additional_information/Licence_number` | `declaration_attached_document.*` |
| 45 | Adjustment factor | `Valuation_item/Rate_of_adjustment` | `declaration_item.adjustment_indicator` |
| 46 | Statistical / customs value | `Statistical_value` | `declaration_item.statistical_value` · `customs_value` |
| 47 | Calculation of taxes | `Taxation/Taxation_line` (see below) | `declaration_tax_line.*` |
| 48 | Deferred payment | `Financial/Deffered_payment_reference` | — |
| 49 | Warehouse identification | `Warehouse/Identification`, `Delay` | `declaration_item.warehouse_id` · `warehouse_days` |

!!! note "Transit & official boxes"
    Transit boxes 50–53 + C/D map to `Transit/Principal`, `Financial/Guarantee`,
    `Transit/Destination/Office`, `Transit/Signature` — see
    [transit & suspense](../schema/transit-suspense.md). Box B (accounting) and
    D/J (control results) are official/server-side; only the assessment identity
    is reconstructed (`declaration.assessment_number`, `assessment_date`).

### The taxation-line sub-table (box 47)

Each `<Item>` carries one `<Tarification>` plus one `<Taxation>` with repeating
`<Taxation_line>`. Confirmed from real declaration XML + `Asycuda421.xsd`:

| AW XML field | Meaning | Toolbox column |
|--------------|---------|----------------|
| `Duty_tax_code` | Tax type (DOG/DDI duty; TVA/TGC VAT; DA excise; RS statistical…) | `declaration_tax_line.tax_type_id` |
| `Duty_tax_Base` | Tax base | `declaration_tax_line.tax_base` |
| `Duty_tax_rate` | Rate (ad valorem, e.g. `0.2`) | `declaration_tax_line.rate_percent` |
| `Duty_tax_amount` | Computed amount | `declaration_tax_line.tax_amount` |
| `Duty_tax_MP` | Mode of payment (1 payable / 0 guaranteed) | `declaration_tax_line.mode_of_payment` |
| `Duty_tax_Type_of_calculation` | Calculation type | `declaration_tax_line.is_manual` (manual vs auto flag) |
| `Item_taxes_amount`, `Global_taxes` | Item / declaration totals | — (derived) |

!!! tip "Assessed lines are server-generated"
    Computed taxation lines and the assigned selectivity lane are **generated
    server-side at assessment** — they appear in the fuller CUSDEC/CUSRES export,
    not in a trader's inbound import-XML. See
    [selectivity & clearance](selectivity-clearance.md).

## Valuation build-up

Invoices are usually FOB but duty is charged on CIF, so AW carries a value
build-up. Each `<Valuation_item>` sub-element (`Invoice`, `External_freight`,
`Internal_freight`, `Insurance`, `Other_cost`, `Deduction`) carries an
`Amount_foreign_currency` + `Currency_code`; the declaration-level `<Valuation>`
adds `Calculation_working_mode` (0 = apportion per value / 1 = per weight /
2 = none). This maps directly onto our two value-note tables:

- `valuation_note` — declaration-level: `total_invoice_fob` + `external_freight`
  + `internal_freight` + `insurance` + `other_costs` → `total_cif`.
- `item_value_note` — per item: `item_fob` + `apportioned_freight` +
  `apportioned_insurance` + `apportioned_other` → `item_cif` (the tax base).

See [declaration → valuation](../schema/declaration.md#valuation-building-the-tax-base)
for the worked split.

## Cargo manifest — AWMDS

The cargo manifest is a separate XML stream, handled by the **ASYFCI** module
(ASYCUDA Fast Cargo Integration) and validated by **`Awmds.xsd`**. Root element
**`<Awmds>`** ("ASYCUDA World Manifest Data Stream"), two segments:

- **`<General_segment>`** — voyage/office IDs, totals, transport info (carrier,
  shipping agent), load/unload UN/LOCODEs, base64 `<Attached_Document>`
  (RFC 2045), coloader, previous-manifest id → our
  [`manifest`](../schema/manifest.md) header.
- **`<Bol_segment>`** (1..∞, one per bill of lading) — `Bol_nature`
  (22 = exports / 23 = imports / 24 = in-transit / 28 = transhipment), traders
  (exporter / notify / consignee), a repeating `<ctn_segment>` (container type,
  empty/full, marks, temperature, dangerous-goods) and `<Goods_segment>` /
  `<Commodity_Segment>` (HS) → our `bill_of_lading`, `container` and
  `manifest_cargo_item` rows.

Companion streams share `<Bol_segment>`: **Degroupage** (`<Awbolds>`,
`Awbolds.xsd`) and **Coloader** (`<Awmcds>`, `Awmcds.xsd`). These XSDs ship
inside the ASYFCI client — they are not canonical UNCTAD downloads; national
portals mirror the spec PDFs.

| AWMDS element | Toolbox table |
|---------------|---------------|
| `<General_segment>` | `manifest` |
| `<Bol_segment>` | `bill_of_lading` (`bl_nature_id` ← `Bol_nature`) |
| `<ctn_segment>` | `container` |
| `<Goods_segment>` / `<Commodity_Segment>` | `manifest_cargo_item` |

## Standards lineage

<div class="grid cards" markdown>

- **WCO Data Model**

    ASYCUDA is "compatible with the WCO data model." WCO DM **v3.6.0 (May 2016)**
    shipped a conformance report of the ASYCUDA information model to the WCO DM
    for SAD import/export data — the mapping bridge. Current WCO DM is **v4.2.0
    (July 2025)**; UNCTAD's public page still references "version 3" (stale).

    !!! note "Evidence gap"
        No public source confirms ASYCUDA natively implements the full **GOVCBR**
        message envelope — conformance is documented at the data-element/SAD
        level, not as a GOVCBR message-structure implementation.

- **EDIFACT lineage (ASYCUDA++)**

    ASYCUDA++ used UN/EDIFACT; AW moved primary exchange to XML while staying
    ++-compatible. Relevant messages: **CUSDEC** (declaration = SAD), **CUSRES**
    (response), **CUSCAR** (cargo report), **CUSREP** (conveyance), **CONTRL**
    (syntax ack). Public EDIFACT CUSDEC XSDs are generic UN/EDIFACT, not
    ASYCUDA-specific.

- **IATA Cargo-XML (air cargo)**

    An official IATA + UNCTAD program. AW accepts **XFFM** (flight manifest),
    **XFWB** (master AWB), **XFZB** (house AWB) and returns **XFNM** (response:
    Processed/Received/Rejected). Requires AW **v4.3.2+**; transport is
    deployment-dependent — **SOAP** or **SMTP/email** for the same message set.

</div>

## Related

- [Declaration — the SAD](../schema/declaration.md) · [Manifest & cargo](../schema/manifest.md)
- [Data dictionary](../schema/data-dictionary.md) · [Querying guide](../guides/querying.md)
- [Integration surfaces](integration.md) · [Selectivity & clearance](selectivity-clearance.md)
- [How faithful is the reconstruction?](../provenance/fit.md)

---
title: Querying the declaration tables
description: >-
  The real SAD tables in ASYCUDA World — SAD_General_Segment, SAD_Item and
  SAD_Tax — their documented columns, and real SQL against them.
tags:
  - querying-sydonia
---

# Querying the declaration tables

The declaration — the **Single Administrative Document** — is the core of
ASYCUDA World's data. Physically it lives in three tables you will query most
often: **`SAD_General_Segment`** (consignment level), **`SAD_Item`** (per
commodity) and **`SAD_Tax`** (per tax line). These names come straight from the
official S014 Declaration Tables and are used verbatim by the toolbox's
[compiler mapping](https://github.com/FrancoisChastel/OpenCustomsToolbox/blob/master/compiler/mappings/asycuda-world.yml).

!!! info "What is pinned vs. instance-specific"
    Column names printed in **bold** are publicly documented (S014 / the XML
    layer) and appear verbatim in the [fit analysis](../provenance/fit.md) — the
    `SAD_Tax` roots, `TAR_HSC_NB1..5`, `VIT_CIF`/`VIT_STV`, the `PTY_*` flags,
    `INSTANCE_ID`. Plain-code names (e.g. `SGS_CUO_COD`) follow AW's prefix
    conventions and match the bundled mock DB, but the exact spelling on a real
    instance is *instance-specific* — confirm it.

## `SAD_General_Segment` — one declaration, repeated per item

The general segment carries the consignment-level facts: office, type, parties,
currency, totals, status and the selectivity colour flags. The catch that defines
querying it: **AW repeats the entire general segment into every item row** — so a
naïve join over items double-counts it. Deduplicate with `DISTINCT` on
**`INSTANCE_ID`** (see [joins & gotchas](joins-and-gotchas.md#repeated-general-segment)).

| Physical column | Meaning | Logical equivalent |
|-----------------|---------|--------------------|
| **`INSTANCE_ID`** | Engine key — the declaration's identity | `declaration.id` |
| `SGS_CUO_COD` | Customs office code | `declaration.office_id` |
| `SGS_TYP_COD` | Declaration model/type (IM4, EX1…) | `declaration.declaration_type_id` |
| `SGS_REG_NBR`, `SGS_REG_DAT` | Registration serial + date | `declaration.registration_number` · `registration_date` |
| `SGS_DEC_REF` | Declarant reference (LRN/UCR) | `declaration.trader_reference` |
| `SGS_EXP_COD`, `SGS_CNE_COD`, `SGS_DCL_COD` | Exporter · consignee · declarant | `declaration.exporter_id` · `consignee_id` · `declarant_id` |
| `SGS_CUR_COD` | Invoice currency | `declaration.currency_id` |
| `SGS_INV_AMT`, `SGS_CIF_AMT` | Total invoice · total CIF | `declaration.total_invoice_amount` · `total_cif_value` |
| **`STA`** | Lifecycle status code | `declaration.status_id` |
| **`PTY_RED`**, **`PTY_YEL`**, **`PTY_GRE`**, **`PTY_BLU`** | Selectivity lane colour flags (`'1'`/`'0'`) | `declaration.selectivity_lane_id` |

The **`STA`** status code drives the clearance state machine (stored →
registered → assessed → paid → released); the **`PTY_*`** flags are a
colour *domain*, not a foreign key — exactly one is set to `'1'`. Decode them with
a `CASE`:

```sql
-- Declarations registered this month, with their assigned lane.
SELECT g.INSTANCE_ID,
       g.SGS_REG_NBR,
       g.SGS_REG_DAT,
       g.STA                                        AS status,
       CASE WHEN g.PTY_RED = '1' THEN 'RED'
            WHEN g.PTY_YEL = '1' THEN 'YELLOW'
            WHEN g.PTY_GRE = '1' THEN 'GREEN'
            WHEN g.PTY_BLU = '1' THEN 'BLUE' END    AS lane
FROM SAD_General_Segment g
WHERE g.SGS_REG_DAT >= DATE '2026-07-01'
ORDER BY g.SGS_REG_DAT;
```

## `SAD_Item` — one row per commodity line

Each item carries the HS code, origin, mass, packages and the valuation values.
Two documented shapes matter here:

- **HS is split across `TAR_HSC_NB1..5`** — five national-precision fragments you
  must concatenate to get a full commodity code
  ([gotcha](joins-and-gotchas.md#hs-split)).
- **`VIT_CIF` is the customs value** (the tax base) and **`VIT_STV` the
  statistical value**; the build-up columns **`VIT_FOB` / `VIT_FRT` / `VIT_INS`**
  hold FOB + apportioned freight + insurance that sum toward CIF.

| Physical column | Meaning | Logical equivalent |
|-----------------|---------|--------------------|
| **`INSTANCE_ID`** | Item identity | `declaration_item.id` |
| `ITM_SGS_ID` | Parent general-segment key | `declaration_item.declaration_id` |
| `ITM_NBR` | Item/line number | `declaration_item.item_number` |
| **`TAR_HSC_NB1..5`** | HS code, split into 5 fragments | `declaration_item.hs_code` (concatenated) |
| **`VIT_CIF`** | Customs value (the tax base) | `declaration_item.customs_value` |
| **`VIT_STV`** | Statistical value | `declaration_item.statistical_value` |
| **`VIT_FOB`**, **`VIT_FRT`**, **`VIT_INS`** | FOB + apportioned freight + insurance → CIF | `item_value_note.item_fob` · `apportioned_freight` · `apportioned_insurance` |
| `ITM_NET_MAS`, `ITM_GRS_MAS` | Net / gross mass | `declaration_item.net_mass` · `gross_mass` |
| `ITM_ORG_COD` | Country of origin | `declaration_item.country_origin_id` |
| `ITM_PKG_NBR` | Number of packages | `declaration_item.number_of_packages` |

```sql
-- Items on one declaration, with the HS code reassembled and the value build-up.
SELECT i.ITM_NBR,
       i.TAR_HSC_NB1 || i.TAR_HSC_NB2 || i.TAR_HSC_NB3
         || i.TAR_HSC_NB4 || i.TAR_HSC_NB5              AS hs_code,
       i.ITM_ORG_COD                                    AS origin,
       i.VIT_FOB, i.VIT_FRT, i.VIT_INS,
       i.VIT_CIF                                        AS customs_value
FROM SAD_Item i
WHERE i.ITM_SGS_ID = 1          -- the declaration's INSTANCE_ID
ORDER BY i.ITM_NBR;
```

!!! note "The build-up is denormalised onto the item"
    Unlike the toolbox's separate `item_value_note` table, the real `SAD_Item`
    carries `VIT_FOB`/`VIT_FRT`/`VIT_INS`/`VIT_CIF` *inline* on the same row. The
    invoice is usually FOB but duty is charged on CIF, so this is where the tax
    base is assembled per item.

## `SAD_Tax` — the tax lines (the pinned roots)

`SAD_Tax` is the one table whose **column roots are fully public**. One row per
item per applicable tax; because taxes cascade (VAT on customs value + duty), the
base is stored per line rather than recomputed.

| Physical column | Meaning | Logical equivalent |
|-----------------|---------|--------------------|
| **`INSTANCE_ID`** | Tax-line identity | `declaration_tax_line.id` |
| `TAX_ITM_ID` | Parent item key | `declaration_tax_line.declaration_item_id` |
| **`COD`** | Tax type (duty / VAT / excise / fee) | `declaration_tax_line.tax_type_id` |
| **`BSE`** | Tax base (amount the rate applies to) | `declaration_tax_line.tax_base` |
| **`RAT`** | Rate (ad valorem) | `declaration_tax_line.rate_percent` |
| **`AMT`** | Computed amount | `declaration_tax_line.tax_amount` |
| **`MOP`** | Mode of payment | `declaration_tax_line.mode_of_payment` |
| **`TYP`** | Manual (`'1'`) vs auto-calculated | `declaration_tax_line.is_manual` |

```sql
-- Duty & VAT collected per declaration, from the real tax roots.
SELECT g.INSTANCE_ID,
       g.SGS_REG_NBR,
       sum(x.AMT) FILTER (WHERE x.COD = 'IMP') AS import_duty,
       sum(x.AMT) FILTER (WHERE x.COD = 'VAT') AS vat,
       sum(x.AMT)                              AS total_tax
FROM SAD_General_Segment g
JOIN SAD_Item i ON i.ITM_SGS_ID = g.INSTANCE_ID
JOIN SAD_Tax  x ON x.TAX_ITM_ID = i.INSTANCE_ID
GROUP BY g.INSTANCE_ID, g.SGS_REG_NBR
ORDER BY total_tax DESC;
```

!!! tip "Manual taxes and totals — the derived siblings"
    - Manual (officer-keyed) taxes live in **`SAD_Ask_Tax`** in the official
      model; the toolbox folds them into `SAD_Tax` via the **`TYP`** flag
      (`TYP = '1'`).
    - **`SAD_Global_Taxes`** and **`SAD_Tax_Totals`** are *summary* tables. Prefer
      to **derive** these by aggregating `SAD_Tax` (as above) rather than trusting
      a possibly-stale total — the toolbox never stores them.

## Assemble a full declaration

Because the general segment repeats, dedupe it before you total taxes — or you
count the header once per item.

```sql
-- Declaration header + item lines + per-item tax, correctly deduplicated.
WITH decl AS (
  SELECT DISTINCT g.INSTANCE_ID, g.SGS_REG_NBR, g.STA
  FROM SAD_General_Segment g
  WHERE g.SGS_DEC_REF = 'REF-2026-0001'
)
SELECT d.SGS_REG_NBR,
       i.ITM_NBR,
       i.TAR_HSC_NB1 || i.TAR_HSC_NB2 || i.TAR_HSC_NB3
         || i.TAR_HSC_NB4 || i.TAR_HSC_NB5   AS hs_code,
       i.VIT_CIF                              AS customs_value,
       sum(x.AMT)                             AS taxes
FROM decl d
JOIN SAD_Item i ON i.ITM_SGS_ID = d.INSTANCE_ID
LEFT JOIN SAD_Tax x ON x.TAX_ITM_ID = i.INSTANCE_ID
GROUP BY d.SGS_REG_NBR, i.ITM_NBR, i.TAR_HSC_NB1, i.TAR_HSC_NB2,
         i.TAR_HSC_NB3, i.TAR_HSC_NB4, i.TAR_HSC_NB5, i.VIT_CIF
ORDER BY i.ITM_NBR;
```

The same query, written against the friendly logical names and compiled for you,
is on the [declaration schema page](../schema/declaration.md#example-assemble-a-declaration).

## Related

- [Manifest tables](manifest-tables.md) — the cargo the declaration writes off.
- [Reference tables](reference-tables.md) — decode `SGS_CUO_COD`, `COD`, `ITM_ORG_COD`.
- [Joins & gotchas](joins-and-gotchas.md) — the dedup, HS-concat and validity traps.
- [XML messages](../platform/xml-messages.md) — the SAD box → XML tag → column map.
- [Declaration schema](../schema/declaration.md) — the same fields, normalised.

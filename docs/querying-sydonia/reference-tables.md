---
title: Querying the reference tables
description: >-
  The UN* / xx*TAB code catalogue in ASYCUDA World — code + name stored inline
  (no FK) and the VALID_FROM/VALID_TO temporal-validity pattern.
tags:
  - querying-sydonia
---

# Querying the reference tables

Everything coded on a declaration or manifest — the office, the country of
origin, the currency, the tax type, the HS chapter, the procedure — resolves
through ASYCUDA World's **reference tables**: the S013 `UN*` / `xx*TAB` code
catalogue. Two patterns define how you query them, and both differ sharply from
the toolbox's normalised `ref_*` model.

!!! info "Two prefixes, one catalogue"
    You will see both **`UN*`** (the shared UNCTAD base, e.g. `UNCTYTAB`) and
    **`xx*TAB`** (national instance tables, where `xx` is the country code) for
    the same domains. The domain roots (`CTY`, `CUR`, `CUO`, `TAX`, `HS`, `CP`…)
    are documented in [S013](../platform/asycuda-world.md); the exact prefix on
    your instance is instance-specific.

## Pattern 1 — code + name stored inline (no foreign key)

The toolbox normalises coded fields into an FK pointing at a `ref_*` table. The
**real AW schema does the opposite**: it stores the **code *and* its name
together on the same row** of the referencing table — e.g. a manifest carries
both `GEN_CAR_COD` and `GEN_CAR_NAM`. The reference table then holds the same
`_COD` + `_NAM` pair as its own two columns.

This is confirmed in the [fit analysis](../provenance/fit.md): *"store code **and**
name inline (`GEN_CAR_COD` + `GEN_CAR_NAM`)"* versus the toolbox's *"FK to a
`ref_*` table"*. Practically, it means **you often do not need to join at all** —
the human-readable name is already sitting beside the code. When you *do* join a
reference table (to filter on validity, or to pull an attribute not denormalised
onto the fact row), you join **on the code**, not on a surrogate id
([details](joins-and-gotchas.md#code-name-inline)).

## Pattern 2 — temporal validity (`VALID_FROM` / `VALID_TO`)

Every `UN*` reference table carries **`VALID_FROM`** and **`VALID_TO`** dates. A
code is only valid for a declaration if the declaration's date falls inside that
window — a currency, tariff line or tax rate can be superseded, and the old row
stays in the table so historical declarations still resolve correctly. An open
`VALID_TO` (`NULL`) means "still current".

The toolbox collapses this to an `is_active` boolean (plus explicit
`valid_from/to` on rate tables), but against the real database **you must filter
by date yourself**, or you will match retired codes and multiply rows.

```sql
-- Currently-valid customs offices (as of today).
SELECT o.CUO_COD, o.CUO_NAM
FROM UNCUOTAB o
WHERE o.VALID_FROM <= CURRENT_DATE
  AND (o.VALID_TO IS NULL OR o.VALID_TO >= CURRENT_DATE)
ORDER BY o.CUO_COD;
```

```sql
-- Resolve a code as it was valid ON a specific declaration date — the correct,
-- point-in-time lookup for historical declarations.
SELECT t.TAX_COD, t.TAX_NAM
FROM UNTAXTAB t
WHERE t.TAX_COD = 'VAT'
  AND t.VALID_FROM <= DATE '2026-07-06'
  AND (t.VALID_TO IS NULL OR t.VALID_TO >= DATE '2026-07-06');
```

!!! warning "Filter to one valid row, or you double-count"
    Skipping the validity predicate is the classic reference-table bug: a code
    that was re-issued has **two rows**, so an unfiltered join returns each fact
    twice. Always constrain to the row valid on the relevant date. The
    [query compiler](../compiler/index.md) injects this filter automatically.

## The main reference tables (S013 crib)

Drawn from the [fit analysis](../provenance/fit.md#reference-module-official-s013-un-tables-our-ref_-tables)
direct-match list. Every one carries the code + name inline and the
`VALID_FROM`/`VALID_TO` window.

| AW table | Domain | Toolbox `ref_*` |
|----------|--------|-----------------|
| `xxCTYTAB` / `UNCTYTAB` | Countries | `ref_country` |
| `xxCURTAB` | Currencies | `ref_currency` |
| `xxRATTAB` | Exchange rates | `ref_exchange_rate` |
| `xxCUOTAB` / `UNCUOTAB` | Customs offices | `ref_customs_office` |
| `xxLOCTAB` | Locations (UN/LOCODE) | `ref_location` |
| `xxMOTTAB` | Transport modes | `ref_transport_mode` |
| `xxPKGTAB` | Package types | `ref_package_type` |
| `xxCTNTAB` | Container types | `ref_container_type` |
| `xxUOMTAB` | Units of measure | `ref_unit_of_measure` |
| `xxTODTAB` | Incoterms | `ref_incoterm` |
| `xxHS1-6TAB` / `xxTARTAB` | Tariff / HS | `ref_hs_tariff` |
| `xxCP1/3/4TAB` | Procedures (CPC / regime) | `ref_cpc_regime` |
| `xxTAXTAB` / `UNTAXTAB` | Tax types | `ref_tax_type` |
| `xxRULTAB` / `xxTAXTAR` | Tax rules / rates | `ref_tax_rate` |
| `xxATDTAB` | Document types | `ref_document_type` |
| `xxCP3TAB` | Exemption / relief codes | `ref_exemption_code` |
| `xxMODTAB` | Declaration types | `ref_declaration_type` |
| `xxNATTAB` | B/L nature | `ref_bl_nature` |
| `xxWHSTAB` | Warehouses | `ref_warehouse` |
| `xxCAR/DEC/CMP/PRPTAB` | Economic operators | `trader` (+ `trader_role`) |

!!! note "Some `UN*` tables are folded inline, not modelled separately"
    Domains such as preference (`xxPRFTAB`), valuation method (`xxVAMTAB`), means
    of payment (`xxMOPTAB`) and quota (`xxQUOTAB`) exist as reference tables in AW
    but the toolbox keeps them as plain coded columns on the fact row rather than
    as separate `ref_*` tables — see the [fit analysis](../provenance/fit.md) and
    [Coverage](../provenance/coverage.md) for the full list and rationale.

## A join that resolves codes correctly

Putting both patterns together — decode a declaration's office and origin against
reference tables, valid on the registration date:

```sql
SELECT g.SGS_REG_NBR,
       o.CUO_NAM                         AS office,
       ctry.CTY_NAM                      AS origin_country
FROM SAD_General_Segment g
JOIN SAD_Item i  ON i.ITM_SGS_ID = g.INSTANCE_ID
JOIN UNCUOTAB o  ON o.CUO_COD = g.SGS_CUO_COD
                AND o.VALID_FROM <= g.SGS_REG_DAT
                AND (o.VALID_TO IS NULL OR o.VALID_TO >= g.SGS_REG_DAT)
JOIN UNCTYTAB ctry ON ctry.CTY_COD = i.ITM_ORG_COD
                  AND ctry.VALID_FROM <= g.SGS_REG_DAT
                  AND (ctry.VALID_TO IS NULL OR ctry.VALID_TO >= g.SGS_REG_DAT)
WHERE g.SGS_DEC_REF = 'REF-2026-0001';
```

## Related

- [Joins & gotchas](joins-and-gotchas.md) — code+name inline and validity, in depth.
- [Declaration tables](declaration-tables.md) · [Manifest tables](manifest-tables.md) — the codes that resolve here.
- [The query compiler](../compiler/index.md) — writes the validity filter for you.
- [Reference & config schema](../schema/reference-config.md) — the normalised `ref_*` side.

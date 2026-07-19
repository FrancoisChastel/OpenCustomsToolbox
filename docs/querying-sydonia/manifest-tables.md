---
title: Querying the manifest tables
description: >-
  The real cargo tables in ASYCUDA World — GEN_TAB, BOL_TAB and CTN_TAB /
  BOL_CTN_TAB — their documented shapes, and real SQL against them.
tags:
  - querying-sydonia
---

# Querying the manifest tables

The **cargo manifest** is what the carrier declares is on board — the upstream
document the importer's declaration later writes off against. Physically it sits
in the S015 Manifest Tables: **`GEN_TAB`** (the manifest general segment),
**`BOL_TAB`** (bills of lading) and **`CTN_TAB`** / **`BOL_CTN_TAB`**
(containers), plus goods lines within each B/L. These table names come from the
official S015 description and the [fit analysis](../provenance/fit.md#manifest-module-official-s015-our-tables);
the XML equivalent is the **AWMDS** stream documented in
[XML messages](../platform/xml-messages.md#cargo-manifest-awmds).

!!! warning "Manifest column names are almost entirely instance-specific"
    S015 pins the **table** names (`GEN_TAB`, `BOL_TAB`, `CTN_TAB`,
    `BOL_CTN_TAB`) and the *field semantics* (voyage, ports, totals, parties,
    seals…), but **not the physical column names** — unlike `SAD_Tax`, no public
    root list exists for the manifest columns. The `GEN_*` / `BOL_*` / `CTN_*`
    names below follow AW's prefix conventions and are *illustrative defaults*.
    Confirm every one against your instance before running.

## `GEN_TAB` — the manifest general segment

One row per manifest: office, voyage/flight, carrier and shipping agent, ports of
loading/unloading, dates, declared totals and status. It is the parent of every
bill of lading on the voyage.

| Physical column | Meaning | Logical equivalent |
|-----------------|---------|--------------------|
| **`INSTANCE_ID`** | Manifest identity (engine key) | `manifest.id` |
| `GEN_CUO_COD` | Customs office of arrival | `manifest.office_id` |
| `GEN_REG_YER`, `GEN_REG_NBR`, `GEN_REG_DAT` | Registration year / number / date | `manifest.manifest_year` · `registration_number` |
| `GEN_VOY_NBR` | Voyage / flight number | `manifest.voyage_number` |
| `GEN_TSP_IDE` | Identity of transport (vessel) | `manifest.identity_of_transport` |
| `GEN_CAR_COD` + `GEN_CAR_NAM` | Carrier — **code and name inline** | `manifest.carrier_id` |
| `GEN_AGT_COD` + `GEN_AGT_NAM` | Shipping agent (code + name inline) | `manifest.shipping_agent_id` |
| `GEN_POL_COD`, `GEN_POD_COD` | Place of loading / unloading (UN/LOCODE) | `manifest.place_departure_id` · `place_destination_id` |
| `GEN_DEP_DAT`, `GEN_ARR_DAT` | Departure / arrival dates | `manifest.date_of_departure` · `date_of_arrival` |
| `GEN_TOT_BOL`, `GEN_TOT_PKG`, `GEN_TOT_CTN`, `GEN_TOT_GRS` | Total B/Ls · packages · containers · gross mass | `manifest.total_bols` · `total_packages` · `total_containers` · `total_gross_mass` |
| `STA` | Manifest lifecycle status | `manifest.status_id` |

!!! note "Carrier is code + name inline"
    Like all AW coded fields, the carrier is stored as **`GEN_CAR_COD` and
    `GEN_CAR_NAM` together on the same row** — there is no FK to a carrier table.
    See [code+name inline](joins-and-gotchas.md#code-name-inline).

## `BOL_TAB` — the bills of lading

One row per transport document. A **master** B/L covers a full container moving
carrier-to-carrier; a **house** B/L is one consignee's consignment inside it
(**degroupage**), expressed by a self-reference on the previous-master B/L
reference.

| Physical column | Meaning | Logical equivalent |
|-----------------|---------|--------------------|
| **`INSTANCE_ID`** | B/L identity | `bill_of_lading.id` |
| `BOL_GEN_ID` | Parent manifest key | `bill_of_lading.manifest_id` |
| `BOL_REF` | B/L reference number | `bill_of_lading.bl_reference` |
| `BOL_LIN_NBR`, `BOL_SUB_NBR` | Line / sub-line number | — |
| `BOL_NAT_COD` | Nature (22 export / 23 import / 24 transit / 28 transhipment) | `bill_of_lading.bl_nature_id` |
| `BOL_MST_REF` | Previous **master** B/L reference (degroupage) | `bill_of_lading.master_bl_id` |
| `BOL_EXP_COD`, `BOL_CNE_COD`, `BOL_NOT_COD` | Exporter · consignee · notify party | — |
| `BOL_PKG_NBR`, `BOL_GRS_MAS`, `BOL_VOL` | Packages · gross mass · volume | `bill_of_lading.number_of_packages` · `gross_mass` |
| `BOL_FRT_AMT`, `BOL_INS_AMT` | Freight / insurance value + currency | — |

```sql
-- All bills of lading on one voyage, with package and mass totals per B/L.
SELECT b.BOL_REF,
       b.BOL_NAT_COD                    AS nature,
       b.BOL_PKG_NBR                    AS packages,
       b.BOL_GRS_MAS                    AS gross_mass,
       CASE WHEN b.BOL_MST_REF IS NULL THEN 'master' ELSE 'house' END AS bl_role
FROM GEN_TAB   g
JOIN BOL_TAB   b ON b.BOL_GEN_ID = g.INSTANCE_ID
WHERE g.GEN_VOY_NBR = 'V2026-042'
ORDER BY b.BOL_REF;
```

## `CTN_TAB` / `BOL_CTN_TAB` — containers & goods lines

Containers are attached to a B/L. Depending on the instance they are held in a
standalone **`CTN_TAB`** or a B/L-scoped **`BOL_CTN_TAB`** junction; both carry
the container reference, ISO 6346 type, empty/full flag, seals, weights, volume
and dangerous-goods flag. Goods/commodity lines (HS, description, packages) sit
within each B/L.

| Physical column | Meaning | Logical equivalent |
|-----------------|---------|--------------------|
| **`INSTANCE_ID`** | Container identity | `container.id` |
| `CTN_BOL_ID` | Parent B/L key | `container.bl_id` |
| `CTN_REF` | Container reference (ISO 6346) | `container.container_number` |
| `CTN_TYP_COD` | Container type code | `container.container_type_id` |
| `CTN_IND` | Empty / full indicator | `container.empty_full` |
| `CTN_PKG_NBR` | Packages inside | `container.number_of_packages` |
| `CTN_GRS_MAS`, `CTN_VOL` | Gross mass · volume | `container.gross_mass` · `volume` |
| `CTN_SEAL` | Seal numbers | `container.seals` |
| `CTN_DGR` | Dangerous-goods flag | `container.dangerous_goods` |

```sql
-- Containers and their B/Ls for an arriving voyage, with fill status.
SELECT b.BOL_REF,
       c.CTN_REF,
       c.CTN_TYP_COD                              AS iso_type,
       CASE WHEN c.CTN_IND = 'F' THEN 'full' ELSE 'empty' END AS fill,
       c.CTN_GRS_MAS                              AS gross_mass
FROM GEN_TAB g
JOIN BOL_TAB b     ON b.BOL_GEN_ID = g.INSTANCE_ID
JOIN CTN_TAB c     ON c.CTN_BOL_ID = b.INSTANCE_ID
WHERE g.GEN_VOY_NBR = 'V2026-042'
ORDER BY b.BOL_REF, c.CTN_REF;
```

!!! info "Vehicle sub-segment — a known gap"
    The manifest XML also defines a **vehicle sub-segment** (chassis/VIN/engine/make
    for RoRo cargo). It is documented but **not modelled** as a table in the
    toolbox — noted in [Coverage](../provenance/coverage.md). If your instance
    carries it, the physical name is instance-specific; request it.

## Grounded in the wire format

Each of these tables maps onto a segment of the **AWMDS** cargo XML stream
(root `<Awmds>`), so the same field semantics are visible two ways:

| AWMDS element | Manifest table | Toolbox table |
|---------------|----------------|---------------|
| `<General_segment>` | `GEN_TAB` | `manifest` |
| `<Bol_segment>` | `BOL_TAB` | `bill_of_lading` |
| `<ctn_segment>` | `CTN_TAB` / `BOL_CTN_TAB` | `container` |
| `<Goods_segment>` / `<Commodity_Segment>` | goods lines in `BOL_TAB` | `manifest_cargo_item` |

## Related

- [Declaration tables](declaration-tables.md) — what clears this cargo.
- [Reference tables](reference-tables.md) — decode office, nature, container type.
- [Joins & gotchas](joins-and-gotchas.md) — `INSTANCE_ID` keys and code+name inline.
- [XML messages — AWMDS](../platform/xml-messages.md#cargo-manifest-awmds) — the cargo stream.
- [Manifest schema](../schema/manifest.md) — the same fields, normalised.

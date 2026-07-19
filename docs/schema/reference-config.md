---
title: Reference & configuration
description: The code-table backbone plus traders and system users.
tags:
  - schema
---

# Reference & configuration

<span class="prov prov--documented">mostly documented</span>
<span class="prov prov--inferred">5 inferred (RBAC + trader_role)</span>

The backbone. Before any manifest or declaration exists, customs needs **code
tables** — countries, currencies, tariff codes, tax types, procedure codes — plus
the **traders** who transact and the **users** who operate the system.
*(GOAL §4.1.)*

## The `ref_*` code tables

Each coded value elsewhere in the model is a **foreign key** into one of these,
rather than an inline code+name pair. Most are grounded directly in the ISO/UN/WCO
standard the customs form references.

| Table | Purpose | Standard / source |
|-------|---------|-------------------|
| `ref_country` | Countries (origin, export, destination, nationality) | ISO 3166 · S008, S013 |
| `ref_currency` | Currencies for invoice / freight / insurance | ISO 4217 · S008, S013 |
| `ref_exchange_rate` | Rate to convert invoice currency (SAD box 23) | S013 (`xxRATTAB`) |
| `ref_customs_office` | Customs offices | S008, S013 |
| `ref_location` | Places / ports of loading, unloading, departure | UN/LOCODE · S008 |
| `ref_transport_mode` | Mode of transport (1 Sea … 9 Unknown) | S008 (full code list) |
| `ref_package_type` | Kind of packages | UN/ECE Rec 21 · S008 |
| `ref_container_type` | Container size-type | ISO 6346 · S008 |
| `ref_unit_of_measure` | Supplementary / statistical units (box 41) | S013 (`xxUOMTAB`) |
| `ref_incoterm` | Delivery terms (box 20) | Incoterms · S012, S003 |
| `ref_hs_tariff` | Commodity codes, self-referential hierarchy (box 33) | Harmonized System · S003, S008 |
| `ref_cpc_regime` | Customs Procedure Codes / regimes (box 37) | S003 (`xxCP*TAB`) |
| `ref_tax_type` | Duty / tax / fee types (box 47) | S003 (`xxTAXTAB`) |
| `ref_tax_rate` | Applicable rate per tax / commodity / origin | S013 (`xxRULTAB`) |
| `ref_document_type` | Attached / supporting document types (box 44) | S003, S008 |
| `ref_exemption_code` | Additional National Codes granting relief (box 37) | S003 |
| `ref_declaration_type` | Declaration type codes (box 1: IM4, EX1…) | S003 |
| `ref_declaration_status` | Declaration lifecycle statuses | S002 |
| `ref_manifest_status` | Manifest lifecycle statuses | S015 |
| `ref_bl_nature` | Transport-document nature (imports/exports/transit) | S008 |
| `ref_selectivity_lane` | Green / yellow / red / blue lanes | S002, S005 |
| `ref_warehouse` | Bonded / customs warehouses (box 49) | S003, S013 |

!!! note "The reference-table pattern"
    Code tables carry a surrogate `id` PK **and** the real business `code`
    (`UNIQUE NOT NULL`). Rate-like tables (`ref_exchange_rate`, `ref_tax_rate`)
    add `valid_from` / `valid_to`; the rest use an `is_active` boolean. This mirrors
    the official `VALID_FROM` / `VALID_TO` temporal pattern seen in the UNCTAD
    reference tables, simplified for a reference model.

## Traders and economic operators

| Table | Purpose | Provenance |
|-------|---------|------------|
| `trader` | Economic operators keyed by TIN — importer, exporter, consignee, declarant, broker, carrier | <span class="prov prov--documented">documented</span> S003, S008 |
| `trader_role` | The role(s) a trader may act in | <span class="prov prov--inferred">inferred</span> normalisation |

A single `trader` can appear as exporter on one declaration and consignee on
another; `trader_role` normalises the roles rather than duplicating the party.

## System users and access control

| Table | Purpose | Provenance |
|-------|---------|------------|
| `sys_user` | People who log in — customs staff, brokers, traders | <span class="prov prov--documented">documented</span> S002 |
| `sys_role`, `sys_permission`, `sys_user_role`, `sys_role_permission` | Role-based access control | <span class="prov prov--inferred">inferred</span> |

ASYCUDA World has role-based menus, but the reference docs publish no user/role
schema — so the RBAC tables are an honest modelling inference (see
[Coverage](../provenance/coverage.md)).

## Resolving a coded column

Because coded columns are foreign keys, "human-readable" queries join to the
`ref_*` table:

```sql
SET search_path TO asycuda, public;

SELECT d.registration_number,
       ty.code   AS decl_type,
       off.name  AS office,
       cur.iso_code AS currency
FROM declaration d
JOIN ref_declaration_type ty  ON ty.id  = d.declaration_type_id
JOIN ref_customs_office   off ON off.id = d.office_id
JOIN ref_currency         cur ON cur.id = d.currency_id;
```

See every column in the [data dictionary](data-dictionary.md#module-reference-configuration-goal-41).

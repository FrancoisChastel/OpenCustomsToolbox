# SOURCES.md — provenance registry

Every `-- src: <ID>` comment in `schema/*.sql` resolves to a row in this
registry, and each `<ID>` denotes a category of **public documentation**
consulted when modelling that table. A cached copy of the material is retained
locally under `sources/` (or `docs/`).

> Specific document titles, publishers, and URLs have been intentionally omitted
> from this registry. The model is grounded in public documentation only —
> restated in the project's own words — not in any proprietary schema or data
> from a live customs system.

## Categories consulted

- Public references on the **Single Administrative Document (SAD)** and Incoterms.
- **National ASYCUDA World user and broker manuals** published by customs
  administrations (declaration processing, manifest/cargo, valuation, suspense).
- **Public ASYCUDA / UNCTAD programme documentation**, including official
  technical table descriptions, processing manuals, and XML message descriptions.
- **Open international standards**: ISO 3166 (countries), ISO 4217 (currencies),
  ISO 6346 (containers), UN/LOCODE, UN/ECE Rec 21 (packages), the Harmonized
  System, the WCO Data Model, Incoterms, and the WTO valuation methods.

## Registry

| ID | Category | Cached |
|----|----------|:------:|
| S001 | Public reference on the SAD declaration | yes |
| S002 | National ASYCUDA World declaration-processing manual | yes |
| S003 | National ASYCUDA World declaration user guide | yes |
| S004 | National ASYCUDA World broker manual | yes |
| S005 | National ASYCUDA World declaration user guide | yes |
| S006 | National ASYCUDA World manifest user guide | yes |
| S007 | National ASYCUDA World manifest user guide | yes |
| S008 | Public ASYCUDA World cargo-manifest XML message description | yes |
| S009 | Public WCO Data Model overview | yes |
| S010 | National ASYCUDA World manifest manual | yes |
| S011 | National ASYCUDA World manifest manual | yes |
| S012 | Public Incoterms reference | yes |
| S013 | Official ASYCUDA World reference-tables description | yes |
| S014 | Official ASYCUDA World declaration-tables description | yes |
| S015 | Official ASYCUDA World manifest-tables description | yes |
| S016 | Official ASYCUDA World accounting-tables description | yes |
| S017 | Official ASYCUDA World SAD processing manual | yes |
| S018 | Official ASYCUDA World introductory manual | yes |
| S019 | ASYCUDA World suspense-declarations manual | yes |
| S020 | Public ASYCUDA World XML manifest message description | yes |

Field semantics were restated in the project's own words; only short field labels
were reused. Where a table could not be grounded in consulted documentation it is
tagged `-- inferred` in the schema and recorded in `COVERAGE.md`.

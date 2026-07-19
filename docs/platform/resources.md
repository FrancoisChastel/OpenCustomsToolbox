---
title: Further reading & document map
description: >-
  A curated, annotated map of the public ASYCUDA documentation landscape — and
  the restricted documents you must request.
tags:
  - platform
---

# Further reading & document map

UNCTAD does not publish ASYCUDA's physical database schema or a machine-readable
API catalog. The field-level model is public **only through the XML layer and
national customs manuals** — so knowing *which* public documents exist is half
the battle. This page distils the public landscape from a deep-research pass over
~90 sources.

!!! note "This complements the schema's own citations"
    [Sources](../provenance/sources.md) lists the **20 documents our schema
    actually cites** (each resolving to a `-- src:` tag). *This* page is broader:
    the wider public reading list for understanding ASYCUDA the platform, not
    just our reconstruction of it.

!!! warning "Fetch caveat"
    Some `unctad.org` PDFs and national portals **bot-block automated fetchers**
    (403 / timeout) though they resolve fine in a browser. National portals
    hosting real samples were the most reliably fetchable during research; some
    scanned/image-only national tariff PDFs blocked text extraction entirely.
    Where an item below is marked *verified*, the research pass confirmed it live.

## Official / spec

The canonical UNCTAD manuals and message specifications.

- **AW Introductory Manual (Part 1)** — [asycuda.world/…/PART_1](https://asycuda.world/downloads/documentation/PART_1_INTRODUCTORY_MANUAL_FOR_ASYCUDA_WORLD.pdf)
- **AW SAD Processing Manual (Part 2)** — the clearance workflow reference — [asycuda.world/…/PART_2](https://asycuda.world/downloads/documentation/PART_2_SAD_PROCESSING_MANUAL_FOR_ASYCUDA_WORLD.pdf)
- **SAD XML Message Description** — the declaration wire spec — [asycuda.douane.aw/…/XML SAD.pdf](https://asycuda.douane.aw/documents/XML%20SAD.pdf)
- **Cargo Manifest XML Message Description** (Aug 2020) — the AWMDS manifest stream — [asycuda.douane.aw/…/XML manifest](https://asycuda.douane.aw/documents/XML%20manifest%20structure%20-%20August%202020.pdf)
- **ASYCUDA official site** (7 languages) — [asycuda.org/en](https://asycuda.org/en/) · Software timeline — [/software](https://asycuda.org/en/software/) · Data Model — [/data-model](https://asycuda.org/en/data-model/)
- **ASYCUDA New Generation ("ASY5") portal** — [newgen.asycuda.org](https://newgen.asycuda.org) · [/asy5](https://newgen.asycuda.org/asy5) · Single Window — [/single-window](https://newgen.asycuda.org/single-window)
- **ASYHUB** (open API platform, connectors, pre-arrival risk) — [asyhub.org/about-asyhub](https://www.asyhub.org/about-asyhub)
- **UNCTAD ASYCUDA Report 2025** — [unctad.org/…/dtlasycuda2025d1](https://unctad.org/system/files/official-document/dtlasycuda2025d1_en.pdf) · **Compendium 2022** — [unctad.org/…/dtlasycuda2022d1](https://unctad.org/system/files/official-document/dtlasycuda2022d1_en.pdf)

## Field-level national manuals — the goldmines

UNCTAD ships AW as a national instance that each country documents itself. These
**[DM]** documents define SAD boxes/fields concretely — often richer than the
UNCTAD spec. Hosting patterns to recognise: `[country].asycuda.org` and
`asycuda.customs.gov.[cc]`.

| Country | Document | Link |
|---------|----------|------|
| Antigua & Barbuda | SAD Fields Guide *(verified)* | [customs.gov.ag/…/FIELDS GUIDE](https://customs.gov.ag/docs/ASYCUDA%20DECLARATION%20FIELDS%20GUIDE.pdf) |
| Uganda (URA) | AW Declaration Processing (Customs) — the primary status-model source | [asyworld.ura.go.ug/…/Customs.pdf](http://asyworld.ura.go.ug/awclient/index_files/AW-User-Manual-Declaration-Processing-Customs.pdf) |
| Botswana (BURS) | CPCs Annex 1 — verbatim Customs Procedure Codes | [burs.org.bw/…/Customs_Procedure_Codes.pdf](https://www.burs.org.bw/phocadownload/customs_and_excise_downloads/Customs_Procedure_Codes.pdf) |
| eSwatini (SRA) | SAD 500 Completion Guide | [asyw.sra.org.sz/…/SAD500 Guide](http://asyw.sra.org.sz/guides/ASYW%20SAD500%20User%20Completion%20Guide%20-%20Final.pdf) |
| Namibia (NamRA) | Entry Processing / SAD 500-501 · Inspection Act FAQ | [namra.org.na/…/entry-processing](https://www.namra.org.na/documents/cms/uploaded/asycuda-entry-processing-system-ad6b63734b.pdf) · [FAQ](https://www.namra.org.na/faqs/faq/what-is-the-inspection-act/) |
| Marshall Islands (RMI) | AW Declaration Submission Guide *(verified)* | [rmi.asycuda.org/…/Submission.pdf](https://rmi.asycuda.org/documents/aw/RMI%20Customs%20User%20Guide%20-%20ASYCUDAWorld%20Declaration%20Submission.pdf) |
| Micronesia (FSM) | Declaration Reference User Guide | [fsm.asycuda.org/…/Declaration_userguide.pdf](https://fsm.asycuda.org/Documents/Declaration_userguide.pdf) |
| Grenada | AW Brokers' Manual | [asycuda.customs.gov.gd/…/broker manual.pdf](https://asycuda.customs.gov.gd/pdf/broker%20manual.pdf) |
| Saint Lucia | Brokers Manual 2023 v3 — four-lane defs, Query Lane, Blue = PCA | [asycuda.customs.gov.lc/…/BROKERS_MANUAL_2023](https://asycuda.customs.gov.lc/documents/CUSTOMS_BROKERS_MANUAL_2023_Version_3.pdf) |
| St. Kitts & Nevis | Processing the SAD | [skncustoms.com/…/Processing the SAD.pdf](https://skncustoms.com/Asycuda%20Manuals/Declaration%20Manual%20Processing%20the%20SAD.pdf) |
| New Caledonia (SYDONIA) | Guide MODBRK — additional codes 33b/37b, 960/940 | [douane.gouv.nc/…/guide_modbrk.pdf](https://douane.gouv.nc/sites/default/files/atoms/files/guide_modbrk.pdf) |

## Real schema, samples & code

The most useful public artifacts for the actual `<ASYCUDA>` wire format — not the
idealized spec, but what real instances export.

- **`Asycuda421.xsd` + serializer** — the most complete public SAD XSD — [github.com/Alphaquest2005/MRManager](https://github.com/Alphaquest2005/MRManager)
- **Real AW declaration XML exports** (IM4/IM7) with JAXB `@XmlRootElement("ASYCUDA")` — [github.com/sc001cs/AsycudaXML](https://github.com/sc001cs/AsycudaXML)
- **St. Kitts & Nevis downloadable sample XMLs** (`SADDEC.XML` / `SADDECVEH.XML`) — [skncustoms.com/…/PageID=327](https://skncustoms.com/Show-Page.aspx?PageID=327)

## ML / selectivity

The dataset, the model, and the live production analogue behind the
[ML risk-engine guide](../guides/ml-risk-engine.md).

- **Korea 62→22 synthetic dataset** — 54k CTGAN records with fraud labels — [github.com/Seondong/Customs-Declaration-Datasets](https://github.com/Seondong/Customs-Declaration-Datasets)
- **DATE** (KDD 2020) — 92.7% precision / 49.3% revenue recall at 1% inspection — [dl.acm.org/…/3403339](https://dl.acm.org/doi/10.1145/3394486.3403339)
- **WCO BACUDA notebooks** — reference open-source analytics — [github.com/YSCHOI-github/Customs_Fraud_Detection](https://github.com/YSCHOI-github/Customs_Fraud_Detection)
- **Nepal Customs CRMS** (real-time ML ↔ ASYCUDA, WCO News Mar 2026, rating A) — [mag.wcoomd.org/…/nepal-customs](https://mag.wcoomd.org/magazine/wco-news-109-issue-1-2026/nepal-customs-automated-risk-analysis-system/)

!!! tip "The hosting-pattern shortcut"
    To find a specific country's manuals and real sample XMLs, try the two
    recurring patterns directly: **`[country].asycuda.org`** (e.g.
    `rmi.asycuda.org`, `fsm.asycuda.org`) and
    **`asycuda.customs.gov.[cc]`** (e.g. `asycuda.customs.gov.lc`,
    `asycuda.customs.gov.gd`). These portal families host the field guides,
    brokers' manuals, and — crucially — real XML samples and message specs.

## Restricted — request via `ASYCUDA@UNCTAD.org`

The load-bearing documents are **not public**. Obtain them through
`ASYCUDA@UNCTAD.org` or your national customs administration's ASYCUDA project
team. Two gated portals:

- **`elearning.asycuda.org`** — 40+ user guides, 100+ videos (Moodle, login required)
- **`gitlab.asycuda.org`** — source + functional/technical specs (credentialed)

What to put on the request list (from the research's gap analysis):

| Request | Why it matters |
|---------|----------------|
| Physical **DB schema / ERD** | The biggest gap — needed for training-data extraction and selectivity write-back |
| **ASYHUB API specification** (OpenAPI/WSDL, auth, message catalog) | The single most important unknown for sanctioned real-time integration |
| **ASY5 "third-party AI → risk profile" signal payload format & endpoint** | The forward-looking injection point; format not yet public |
| **Asysel** admin data model (operators, priority, validity, AND/OR, score→lane thresholds) | Deliberately hidden to prevent gaming |
| **Inspection-Act read access** (illicit flag + recovered revenue) | The ML labels and the feedback loop depend on it |

---

<small>Every URL on this page appears in the deep-research bibliography (~90
annotated sources). Source ratings — A official/peer-reviewed, B national
official/recovered spec, C vendor/secondary — carry through from that pass; the
ML/selectivity claims trace to specific ratings noted in the
[ML risk-engine guide](../guides/ml-risk-engine.md).</small>

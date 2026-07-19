---
title: ASYCUDA World — the modeled version
description: >-
  What ASYCUDA World (v4) is, its XML e-document model and closed client
  protocol, and exactly what this toolbox reconstructs from it.
tags:
  - platform
---

# ASYCUDA World — the modeled version

This is the version the Open Customs Toolbox models. Everything in the
[Schema](../schema/index.md) tab is a reconstruction of **ASYCUDA World (v4)** —
so it is worth knowing what the real platform is, how it stores data, and where
the line falls between what is public and what is not.

## What ASYCUDA World is

ASYCUDA World has been UNCTAD's current standard since **2002**, running in
**100+ countries and territories**. It is **100% Java**, built as a **web /
store-and-forward N-tier** system. The store-and-forward design is deliberate:
the client does not need a permanent connection to the server, which is what
makes it workable in countries with weak or intermittent telecoms — a declaration
can be captured offline and forwarded when a connection returns.

It is database-agnostic. A national instance can run on **Oracle, MS SQL Server,
MySQL, PostgreSQL, DB2, Sybase, or Informix**. The application layer is the same
Java stack regardless of which database sits underneath.

## The XML e-document model

ASYCUDA World does not store business objects the way you might expect a
relational system to. Every business object — a declaration, a manifest, a
receipt — is a **non-namespaced XML document**. The Java client can **Export XML
File** and **Import XML File** for these documents, and this XML layer is the
public window onto the field-level model.

The declaration — the Single Administrative Document (SAD) — is structured as two
kinds of segment:

- A **general segment**: one per consignment, carrying parties, transport,
  valuation totals and identification.
- Repeating **item segments**: one per commodity line, each with HS code, origin,
  mass, value and taxes.
- Plus up to five **additional forms** extending the item detail.

Field values follow a small set of data types:

| Type | Meaning |
|------|---------|
| `INT` | integer |
| `N#` | decimal number |
| `AN#` | alphanumeric |
| `DATE` | date, `yyyy-MM-dd` |
| `TIME` | time, `hh:mm:ss` |
| `BOOLEAN` | true / false |

One declaration per file; multiple items per declaration; extra tags are ignored
on import. The mechanics of the wire format, the `<ASYCUDA>` root and the
Box → tag map are covered in [XML messages](xml-messages.md).

## The client and its closed protocol

The ASYCUDA World client is a **Java Web Start thick client**: a `.jnlp` launch
file pulls roughly **130 JARs** over HTTPS, the main class is
`so.kernel.client.DesktopMain`, and it connects to the national server over a
**custom TCP port** (for example `//host:2016/`). That connection is a
**proprietary object/XML protocol — not SOAP, not REST.**

!!! warning "Do not integrate at the client protocol"

    The client-to-server socket (`so.kernel`, port ~2016) is a closed,
    proprietary protocol. It is not a supported integration surface, and building
    against it is fragile and unsanctioned. Real integration happens elsewhere —
    the RDBMS, ASYHUB, IATA Cargo-XML, or XML file import. See
    [Integration surfaces](integration.md) for the doors that actually exist.

## What this toolbox models

The toolbox reconstructs the ASYCUDA World data model as a clean, normalised
PostgreSQL schema. It is grounded in the **official UNCTAD/DTL ASYCUDA World
Tables Description v0.1.0905** documents:

| Source | Covers |
|--------|--------|
| **S013** | Reference tables (the `UN*` code-table catalogue) |
| **S014** | Declaration tables (`SAD_General_Segment`, `SAD_Item`, `SAD_Tax`, selectivity, inspection…) |
| **S015** | Manifest tables (`GEN_TAB`, `BOL_TAB`, containers, transit) |
| **S016** | Accounting tables (receipts, `TAX_TAB`, account transactions) |

See [Sources](../provenance/sources.md) for the full registry.

There is a deliberate difference between the official model and ours. ASYCUDA
World's **official physical schema is wide and denormalised** — and it is **not
published** by UNCTAD. What this toolbox provides is an **information-equivalent
reference**: a normalised model that carries the same field-level information,
restructured to be readable and queryable. It is not a byte-for-byte copy of the
real tables; it is a faithful reconstruction of what they hold.

The table-by-table mapping between our reconstruction and the official tables —
including the deliberate structural differences — is in
[Official fit & gap](../provenance/fit.md), and the schema itself starts at the
[Schema overview](../schema/index.md).

## Where the public docs live

The field-level model is public *only through the XML layer and national
manuals* — never as a published database schema. The documentation lives in a few
predictable places:

- **UNCTAD official:** `asycuda.org`, and the ASYCUDA World manuals on
  `asycuda.world` — Part 1 (Introductory) and Part 2 (SAD Processing).
- **National customs portals:** each country documents its own instance, hosted
  on the recurring patterns `[country].asycuda.org` and
  `asycuda.customs.gov.[cc]`. These SAD field guides and broker manuals are the
  richest public window onto the model.
- **Restricted (member customs only):** the e-learning platform
  (`elearning.asycuda.org`) and developer GitLab (`gitlab.asycuda.org`), plus the
  core functional and technical reference manuals. Request access via
  **ASYCUDA@UNCTAD.org** or a national customs ASYCUDA project team.

The full annotated list is on the [Resources](resources.md) page.

## Next

- [XML messages](xml-messages.md) — the `<ASYCUDA>` document format and the
  Box → tag map.
- [Integration surfaces](integration.md) — the real doors for reading and
  writing ASYCUDA data.
- [Selectivity & clearance](selectivity-clearance.md) — the risk lanes and the
  clearance state machine.

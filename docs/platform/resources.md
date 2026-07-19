---
title: Further reading & document map
description: >-
  How ASYCUDA documentation is generally obtained — public programme materials,
  national customs manuals, open standards, and the specs you must request.
tags:
  - platform
---

# Further reading & document map

UNCTAD does not publish ASYCUDA's physical database schema or a machine-readable
API catalog. The field-level model is public **only through the XML layer and
national customs manuals** — so knowing *which kinds* of documents exist, and
where they normally live, is half the battle. This page describes the shape of
that landscape without pointing at any one document.

!!! note "This complements the schema's own citations"
    [Sources](../provenance/sources.md) lists the documents our schema **actually
    cites** (each resolving to a `-- src:` tag). *This* page is broader: a general
    guide to the kinds of public reading that help you understand ASYCUDA the
    platform, not just our reconstruction of it.

## The kinds of documentation, and where they live

Understanding ASYCUDA from public material means drawing on a few recurring
categories. None of them is a single authoritative schema — together they are the
public window onto the model.

### Public programme materials

The ASYCUDA programme publishes introductory and processing manuals, message
specifications and general platform documentation. These describe the SAD
workflow, the XML e-document model and the overall system at a conceptual level.
They are the canonical starting point for what the platform *is*.

### National customs manuals — the field-level goldmines

ASYCUDA World is deployed as a national instance, and each administration
documents its own instance. These national user guides, broker manuals and SAD
field guides define the declaration boxes and fields concretely — often in more
practical detail than the general programme material — because they describe the
system as traders and officers actually use it. They are typically hosted on the
national customs administration's own portal.

### Real schemas, samples & code

The most useful public artefacts for the actual XML wire format are the real
instances themselves: exported declaration and manifest XML, recovered schema
definitions, and integrator code that reads or writes the `<ASYCUDA>` format.
These show what real instances export, as opposed to the idealised specification.

### Open standards

The surrounding standards are fully public and stable: ISO country/currency
codes, the UN trade and transport code lists, the WCO Harmonized System and Data
Model, Incoterms, and the WTO valuation framework. ASYCUDA aligns to these, so
they are load-bearing background reading in their own right.

### Public customs-ML research and open datasets

For the analytics and risk-engine side, there is a body of public customs
machine-learning research and a small number of open, downloadable customs
datasets. These describe feature schemas, modelling approaches and evaluation
methods generically — enough to prototype a risk model before you have access to
real declaration history. See the [ML risk-engine guide](../guides/ml-risk-engine.md)
for how that research shapes the blueprint.

## Restricted — request via your national customs or the ASYCUDA programme

The load-bearing technical documents are **not public**. The physical database
schema / ERD, the ASYHUB API specification, the ASY5 risk-signal payload format,
the selectivity admin data model, and Inspection-Act read access are all obtained
by request — through your national customs administration's ASYCUDA project team
or the UNCTAD ASYCUDA programme. Gated learning platforms and credentialed
developer repositories exist for member customs administrations but are not open
to the public.

What to put on the request list:

| Request | Why it matters |
|---------|----------------|
| Physical **DB schema / ERD** | The biggest gap — needed for training-data extraction and selectivity write-back |
| **ASYHUB API specification** (OpenAPI/WSDL, auth, message catalog) | The single most important unknown for sanctioned real-time integration |
| **ASY5 "third-party AI → risk profile" signal payload format & endpoint** | The forward-looking injection point; format not yet public |
| **Selectivity admin data model** (operators, priority, validity, score→lane thresholds) | Deliberately hidden to prevent gaming |
| **Inspection-Act read access** (illicit flag + recovered revenue) | The ML labels and the feedback loop depend on it |

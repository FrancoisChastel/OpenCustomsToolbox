---
title: The platform
description: >-
  ASYCUDA the software — which version this toolbox models, how the generations
  differ, the XML wire formats, integration surfaces and the clearance process.
tags:
  - platform
---

# The ASYCUDA platform

The [Schema](../schema/index.md) section documents **our reconstruction**. This
section documents **ASYCUDA itself** — the software the reconstruction models —
so you can place the toolbox against the real system you are working with:
which generation it is, how its data leaves the system, and where an external
system can plug in.

!!! success "Which version does this toolbox model?"
    **ASYCUDA World (v4)** — the current standard, used by 100+ countries. The
    schema is grounded in public UNCTAD/ASYCUDA programme table descriptions plus
    ASYCUDA World national manuals and message specs (see
    [Sources](../provenance/sources.md)). If your deployment is ASYCUDA World,
    this model is a direct reference; if it is ASYCUDA++ or ASY5, see the
    [version lineage](versions.md) for what changes.

## Which version do *you* have?

Three quick fingerprints (details on the [versions page](versions.md)):

| If you see… | You are on |
|-------------|-----------|
| A **Java** client launched via `.jnlp` (Java Web Start), declarations exported as **XML** files | **ASYCUDA World (v4)** — what this toolbox models |
| A **C++** thick client, **UN/EDIFACT** messages (CUSDEC/CUSRES), Oracle/Informix/Sybase | **ASYCUDA++ (v3)** — legacy, same SAD data model, different exchange layer |
| Cloud-native microservices (Quarkus, Kubernetes, Kafka), REST/event APIs | **ASY5 / New Generation** — phased rollout (Angola live Jan 2026) |

The SAD declaration model — general segment + item segments — is stable across
++ and World, so the [schema](../schema/index.md) remains a valid reference for
both; what changes between generations is the technology and the integration
surfaces.

## Explore

<div class="grid cards" markdown>

-   :material-timeline-clock:{ .lg .middle } &nbsp;**Version lineage**

    ---

    Five generations from 1981 to ASY5 — what each changed, and how to
    fingerprint the one in front of you.

    [:octicons-arrow-right-24: Versions](versions.md)

-   :material-earth:{ .lg .middle } &nbsp;**ASYCUDA World**

    ---

    The modeled version in depth: the XML e-document model, the client, the
    closed protocol, and how our schema relates to the real one.

    [:octicons-arrow-right-24: ASYCUDA World](asycuda-world.md)

-   :material-xml:{ .lg .middle } &nbsp;**XML messages & wire format**

    ---

    The SAD Box → XML tag → toolbox column map, the `<ASYCUDA>` wire-format
    gotcha, the AWMDS manifest stream, WCO DM and EDIFACT.

    [:octicons-arrow-right-24: XML messages](xml-messages.md)

-   :material-connection:{ .lg .middle } &nbsp;**Integration surfaces**

    ---

    The doors that actually exist — RDBMS/ETL, ASYHUB, Cargo-XML, XML import,
    ASY5 — and the specs you must request.

    [:octicons-arrow-right-24: Integration](integration.md)

-   :material-traffic-light:{ .lg .middle } &nbsp;**Selectivity & clearance**

    ---

    The clearance state machine (C/L/PRN serials) and the four-lane risk model,
    mapped to our tables.

    [:octicons-arrow-right-24: Selectivity & clearance](selectivity-clearance.md)

-   :material-book-open-variant:{ .lg .middle } &nbsp;**Further reading**

    ---

    The curated public-document map — official manuals, national field guides,
    real XML samples, ML datasets — and what is restricted.

    [:octicons-arrow-right-24: Resources](resources.md)

</div>

## Doing ML on customs data?

That is what this platform knowledge is for: the
[ML risk-engine guide](../guides/ml-risk-engine.md) turns it into a working
blueprint — features, labels, the lane loop, and how to prototype on this
toolbox's schema before you have access to a live system.

---

<small>Platform facts on these pages are distilled from the public ASYCUDA record —
UNCTAD programme documents, national customs manuals, recovered schemas and real
declaration samples. Where something is not publicly documented — the physical DB
schema, the ASYHUB API — these pages say so plainly rather than guessing.</small>

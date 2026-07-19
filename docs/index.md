---
title: Open Customs Toolbox
description: >-
  A faithful, fully-sourced PostgreSQL reference data model of UNCTAD ASYCUDA
  World (SYDONIA), reconstructed from public documentation.
hide:
  - navigation
  - toc
---

<div class="oct-hero" markdown="1">
<span class="oct-hero__eyebrow">:material-anchor: SYDONIA · ASYCUDA World · PostgreSQL</span>

# The customs data model, reconstructed in the open

A faithful, **fully-sourced** relational model of the UNCTAD **ASYCUDA World
(SYDONIA)** customs management system — manifests, SAD declarations, valuation,
taxes, selectivity, accounting and suspense regimes — ready to `psql` into a
sandbox, an analytics warehouse, or an integration test bed.

<div class="oct-hero__cta">
<a class="oct-btn oct-btn--primary" href="getting-started/quickstart/">Quickstart →</a>
<a class="oct-btn oct-btn--ghost" href="schema/">Explore the schema</a>
<a class="oct-btn oct-btn--ghost" href="https://github.com/FrancoisChastel/OpenCustomsToolbox">GitHub</a>
</div>
</div>

<div class="oct-stats" markdown>
<div class="oct-stat"><b>55</b><span>tables across 8 modules</span></div>
<div class="oct-stat"><b>49&nbsp;/&nbsp;6</b><span>documented / inferred</span></div>
<div class="oct-stat"><b>20</b><span>cited public sources</span></div>
<div class="oct-stat"><b>0</b><span>errors on a clean load</span></div>
</div>

## Why it exists

ASYCUDA World is the customs platform used by **100+ countries**, but its
internal database schema is proprietary. This project rebuilds an
**information-equivalent reference model** using *only* public documentation —
UNCTAD/DTL technical table descriptions, national ASYCUDA World user manuals,
and open ISO/UN/WCO standards. Every table is traceable to a citation, or is
honestly flagged as inferred.

The modeled version is **ASYCUDA World (v4)** — the current standard. The
[platform section](platform/index.md) covers the full version lineage
(ASYCUDA++ → World → ASY5), the XML wire formats, and where external systems
can integrate, so you can place this model against the deployment you actually
have.

!!! quote "Scope, stated plainly"
    This is a **functional/reference reconstruction** for sandbox, integration,
    analytics and training use. It is **not** an attempt to obtain or reproduce
    UNCTAD's proprietary internal schema, and it contains no pirated software or
    data from any live customs system.

## What you can do with it

<div class="grid cards" markdown>

-   :material-database-import:{ .lg .middle } &nbsp;**Stand up a customs sandbox**

    ---

    One `psql` command loads a clean schema, seed reference data, and a fully
    worked manifest→release example. PostgreSQL 14+.

    [:octicons-arrow-right-24: Quickstart](getting-started/quickstart.md)

-   :material-file-tree:{ .lg .middle } &nbsp;**Understand the customs domain**

    ---

    A guided map of manifests, the SAD declaration, valuation build-up,
    per-item taxes, selectivity lanes and the document lifecycle.

    [:octicons-arrow-right-24: Customs concepts](getting-started/concepts.md)

-   :material-magnify:{ .lg .middle } &nbsp;**Query real join paths**

    ---

    A cookbook of the join paths that matter: declaration → item → tax line,
    manifest → B/L → cargo, assessed-vs-paid reconciliation.

    [:octicons-arrow-right-24: Querying guide](guides/querying.md)

-   :material-source-branch:{ .lg .middle } &nbsp;**Extend it safely**

    ---

    Add tables and columns while keeping the conventions and the provenance
    trail intact, so your fork stays as auditable as the original.

    [:octicons-arrow-right-24: Extending guide](guides/extending.md)

-   :material-shield-check:{ .lg .middle } &nbsp;**Trust the sourcing**

    ---

    Every `CREATE TABLE` carries a `-- src:` or `-- inferred` tag. Coverage and
    an official fit/gap analysis are published in full.

    [:octicons-arrow-right-24: Provenance](provenance/index.md)

-   :material-robot-happy:{ .lg .middle } &nbsp;**Drive it with Claude Code**

    ---

    A suite of Claude Code Skills that set up, query, seed, extend and validate
    the model directly inside your own codebase.

    [:octicons-arrow-right-24: Claude Code skills](skills/index.md)

-   :material-earth:{ .lg .middle } &nbsp;**Know the platform**

    ---

    ASYCUDA itself: the version lineage (v1 → World → ASY5), the XML wire
    formats, the integration doors, and the clearance process.

    [:octicons-arrow-right-24: The platform](platform/index.md)

-   :material-brain:{ .lg .middle } &nbsp;**Build ML on it**

    ---

    The research-backed blueprint for ML on declarations and plugging a risk
    engine into selectivity — prototyped on this schema.

    [:octicons-arrow-right-24: ML on customs data](guides/ml-risk-engine.md)

</div>

## A 30-second taste

```bash
createdb customs_sandbox
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/schema/asycuda.sql
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/schema/seed_reference.sql
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/examples/e2e.sql
```

```text
--- Declaration summary ---
  reg  | type |  status  | lane | total_items | total_cif_value
-------+------+----------+------+-------------+-----------------
 C 427 | IM4  | released | RED  |           2 |      63300.0000

--- Total assessed vs receipt ---
 total_assessed | receipt_amount
----------------+----------------
     12132.5000 |     12132.5000
```

A single import declaration — two items, freight and insurance apportioned to
per-item CIF, duties and VAT calculated, routed to the RED lane, inspected,
paid and released — inserts with full referential integrity.

## For large-language-model consumption

This site publishes an [`llms.txt`](llms.txt) index and a concatenated
[`llms-full.txt`](llms-full.txt) so you can hand the entire model to an LLM in
one paste. See the [Claude Code skills](skills/index.md) to wire it into an
agent workflow.

---

<small>Open Customs Toolbox is independent and reconstructed from public
documentation. ASYCUDA and SYDONIA are programmes of UNCTAD; this project is not
affiliated with or endorsed by UNCTAD.</small>

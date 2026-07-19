---
title: Sydonia Toolkit
description: >-
  A faithful, fully-sourced PostgreSQL reference data model of UNCTAD ASYCUDA
  World (SYDONIA), reconstructed from public documentation.
hide:
  - navigation
  - toc
---

<div class="syt-hero" markdown="1">
<span class="syt-hero__eyebrow">:material-anchor: SYDONIA · ASYCUDA World · PostgreSQL</span>

# Query Sydonia: write friendly, run genuine

Write customs analytics against a **friendly logical model** — `declaration`,
`declaration_item`, `hs_code`, `tax_amount` — and **compile them to genuine
ASYCUDA World (SYDONIA) SQL you can actually run**, read-only, against a real
instance. The abstraction is easy; the output is real. Underneath is a faithful,
**fully-sourced** reconstruction of the whole customs model — now the logical
layer the compiler maps *from*.

<div class="syt-hero__cta">
<a class="syt-btn syt-btn--primary" href="compiler/">Query Sydonia →</a>
<a class="syt-btn syt-btn--ghost" href="getting-started/quickstart/">Quickstart</a>
<a class="syt-btn syt-btn--ghost" href="schema/">Explore the schema</a>
<a class="syt-btn syt-btn--ghost" href="https://github.com/FrancoisChastel/sydonia-toolkit">GitHub</a>
</div>
</div>

<div class="syt-stats" markdown>
<div class="syt-stat"><b>55</b><span>tables across 8 modules</span></div>
<div class="syt-stat"><b>49&nbsp;/&nbsp;6</b><span>documented / inferred</span></div>
<div class="syt-stat"><b>100%</b><span>cited public sourcing</span></div>
<div class="syt-stat"><b>0</b><span>errors on a clean load</span></div>
</div>

## Why it exists

ASYCUDA World is the customs platform used by **100+ countries**, but its
internal database schema is **wide, denormalised and proprietary** — painful to
query for analytics. So this project does two things. It rebuilds an
**information-equivalent reference model** using *only* public documentation —
official public technical table descriptions, national ASYCUDA World user manuals,
and open ISO/UN/WCO standards, every table traceable to a citation or honestly
flagged as inferred. And it ships a [**query compiler**](compiler/index.md) that
lets you write against that clean model and **compile to genuine Sydonia SQL** —
so the friendly names are the ergonomics, and the runnable statement is real.

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

-   :material-cog-transfer:{ .lg .middle } &nbsp;**Compile to genuine Sydonia SQL**

    ---

    Write a query against the friendly logical model; the compiler rewrites it
    into runnable ASYCUDA World SQL via a CTE prelude. **Write friendly, run
    genuine.**

    [:octicons-arrow-right-24: The query compiler](compiler/index.md)

-   :material-database-search:{ .lg .middle } &nbsp;**Query a real ASYCUDA World**

    ---

    Point the same queries and skills at a live instance — read-only, metadata
    only — for analytics, feature extraction and selectivity on *your* data.

    [:octicons-arrow-right-24: Querying Sydonia](querying-sydonia/index.md)

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

-   :material-robot-happy:{ .lg .middle } &nbsp;**Drive it with Agent Skills**

    ---

    A suite of standard Agent Skills — installable into any agent (Claude Code,
    Cursor, Codex, …) via `npx skills add` — that set up, query, seed, extend and
    validate the model directly inside your own codebase.

    [:octicons-arrow-right-24: Agent Skills](skills/index.md)

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
one paste. See the [Agent Skills](skills/index.md) to wire it into an
agent workflow.

---

<small>Sydonia Toolkit is independent and reconstructed from public
documentation. ASYCUDA and SYDONIA are programmes of UNCTAD; this project is not
affiliated with or endorsed by UNCTAD.</small>

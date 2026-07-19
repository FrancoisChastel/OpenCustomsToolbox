---
title: Getting started
description: Install, load and understand the Open Customs Toolbox in minutes.
---

# Getting started

Three short pages take you from an empty database to understanding what every
table means.

<div class="grid cards" markdown>

-   :material-rocket-launch:{ .lg .middle } &nbsp;**Quickstart**

    ---

    The fastest path: create a database, load three SQL files, and watch a full
    customs declaration flow through to release.

    [:octicons-arrow-right-24: Quickstart](quickstart.md)

-   :material-cog:{ .lg .middle } &nbsp;**Installation**

    ---

    Prerequisites, PostgreSQL versions, Docker vs local, the `asycuda` schema,
    idempotent reloads, and teardown.

    [:octicons-arrow-right-24: Installation](installation.md)

-   :material-school:{ .lg .middle } &nbsp;**Customs concepts**

    ---

    A domain primer — manifest, bill of lading, the SAD declaration, valuation,
    taxes, selectivity and the lifecycle — mapped to tables.

    [:octicons-arrow-right-24: Customs concepts](concepts.md)

</div>

New to the customs domain? Read **Customs concepts** first — it makes the schema
read like a story instead of 55 tables.

Once the sandbox is up, the main event is querying: **[Querying
Sydonia](../querying-sydonia/index.md)** explains the real ASYCUDA World tables,
and **[the query compiler](../compiler/index.md)** turns friendly logical queries
into genuine Sydonia SQL you can run on a live system.

---
title: Guides
description: Task-oriented guides — load, query, extend, and take the model to a real Sydonia.
---

# Guides

Task-oriented walkthroughs for working with the model day to day.

!!! tip "Querying a real ASYCUDA World system?"
    These guides use the friendly **logical model**. To run the same queries on a
    live Sydonia, see **[Querying Sydonia](../querying-sydonia/index.md)** (the
    real tables) and **[the query compiler](../compiler/index.md)** (write
    friendly, run genuine).

<div class="grid cards" markdown>

-   :material-database-arrow-down:{ .lg .middle } &nbsp;**Loading the schema**

    ---

    Integration patterns beyond the quickstart — CI, test resets, loading
    alongside your own tables, and namespacing.

    [:octicons-arrow-right-24: Loading](loading.md)

-   :material-magnify:{ .lg .middle } &nbsp;**Querying the model**

    ---

    The join paths that matter, plus an analytics cookbook: revenue by HS,
    assessed-vs-paid, lane throughput, warehouse stock.

    [:octicons-arrow-right-24: Querying](querying.md)

-   :material-source-branch:{ .lg .middle } &nbsp;**Extending the schema**

    ---

    Add tables and columns while keeping the conventions — and the provenance
    trail — intact.

    [:octicons-arrow-right-24: Extending](extending.md)

-   :material-play-box:{ .lg .middle } &nbsp;**Worked example**

    ---

    `e2e.sql`, narrated step by step: manifest → declaration → valuation →
    taxes → selectivity → payment → release.

    [:octicons-arrow-right-24: Worked example](worked-example.md)

-   :material-table-search:{ .lg .middle } &nbsp;**Useful queries**

    ---

    A growing, verified library of analytical queries — effective rates,
    valuation outliers, selectivity hit-rates — with a copy-paste format.

    [:octicons-arrow-right-24: Useful queries](useful-queries.md)

-   :material-brain:{ .lg .middle } &nbsp;**ML on customs data**

    ---

    The risk-engine blueprint: features mapped to SAD boxes and columns, labels
    from the Inspection Act, the selectivity loop.

    [:octicons-arrow-right-24: ML on customs data](ml-risk-engine.md)

</div>

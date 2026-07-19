---
title: Provenance
description: How every table is sourced, how far coverage goes, and how it fits the official model.
tags:
  - provenance
---

# Provenance

The credibility of this project rests on one promise: **every table is either
grounded in a cited public source or honestly marked as inferred — nothing is
invented and dressed up as documented.** This section is the evidence.

<div class="oct-stats" markdown>
<div class="oct-stat"><b>49</b><span>tables documented (<code>-- src:</code>)</span></div>
<div class="oct-stat"><b>6</b><span>tables inferred (<code>-- inferred</code>)</span></div>
<div class="oct-stat"><b>20</b><span>cited, cached sources</span></div>
<div class="oct-stat"><b>0</b><span>fabricated citations</span></div>
</div>

<div class="grid cards" markdown>

-   :material-compass:{ .lg .middle } &nbsp;**Methodology**

    ---

    The evidence-first reconstruction loop, the source policy, and the
    verification checks that gate "done".

    [:octicons-arrow-right-24: Methodology](methodology.md)

-   :material-bookshelf:{ .lg .middle } &nbsp;**Sources**

    ---

    All 20 cited public documents — UNCTAD/DTL technical tables, national
    ASYCUDA World manuals, and open standards — with URLs and notes.

    [:octicons-arrow-right-24: Sources](sources.md)

-   :material-format-list-checks:{ .lg .middle } &nbsp;**Coverage**

    ---

    Every module and table, marked documented / partial / inferred, with the
    known gaps stated plainly.

    [:octicons-arrow-right-24: Coverage](coverage.md)

-   :material-vector-difference:{ .lg .middle } &nbsp;**Official fit & gap**

    ---

    Our reconstruction mapped table-by-table against the official UNCTAD/DTL
    ASYCUDA World tables — where it fits, and where it deliberately differs.

    [:octicons-arrow-right-24: Fit & gap](fit.md)

</div>

## Read the provenance yourself

You don't have to take these pages on faith. The evidence is in the repository:

```bash
# every CREATE TABLE carries a -- src: or -- inferred tag
grep -niE 'create[ \t]+table' Sydonia/schema/asycuda.sql

# every cited ID resolves to a row in SOURCES.md and a cached file under sources/
grep -oiE '\-\- src: *S[0-9, ]+' Sydonia/schema/asycuda.sql | grep -oiE 'S[0-9]+' | sort -u
```

The [`customs-validate`](../skills/index.md) skill automates exactly this audit.

---
title: Data dictionary
description: Every table and column — purpose, type, nullability and source.
tags:
  - schema
  - reference
---

# Data dictionary

Every table and column in the model, grouped by module. Each entry lists the
column's type, nullability, and — at the table level — its provenance
(`-- src: <ID>` or `-- inferred`). This page is generated from the live
PostgreSQL catalog after loading `Sydonia/schema/asycuda.sql`, so it is exact.

!!! tip "Looking for one table?"
    Use the search box (press <kbd>/</kbd>) or your browser's find — every table
    name is a heading anchor. For the visual shape, see the
    [entity-relationship diagram](erd.md).

--8<-- "Sydonia/DATA_DICTIONARY.md:9:813"

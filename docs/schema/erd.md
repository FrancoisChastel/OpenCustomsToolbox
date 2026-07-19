---
title: Entity-relationship diagram
description: Every foreign key in the model, rendered from the loaded schema.
tags:
  - schema
---

# Entity-relationship diagram

This diagram is generated from the **loaded schema's foreign keys**, so it always
matches `Sydonia/schema/asycuda.sql`. The `ref_*` / `sys_*` tables are the
code/config backbone; the manifest and declaration clusters are the operational
core. Attributes are abbreviated to primary/business keys for legibility — see
the [data dictionary](data-dictionary.md) for the full column list.

--8<-- "Sydonia/ERD.md:8:331"

---
title: Joins & gotchas
description: >-
  The five things that bite when querying a real ASYCUDA World database —
  INSTANCE_ID keys, the repeated general segment, the HS split, code+name inline,
  and reference validity — each with its symptom and its fix.
tags:
  - querying-sydonia
---

# Joins & gotchas

Querying the real ASYCUDA World database is not hard because the SQL is exotic —
it is hard because the schema is **wide and denormalised** in five specific ways
that quietly produce wrong answers. Each one below is drawn from the
["Aspect" table in the fit analysis](../provenance/fit.md#verdict) and reproduced
in the toolbox's [mock database](https://github.com/FrancoisChastel/sydonia-toolkit/blob/master/Sydonia/adapters/mock_asycuda_world.sql).
For each: the **symptom** you will see, and the **fix**.

## 1. `INSTANCE_ID` — the engine keys {: #instance-id }

AW keys rows on **`INSTANCE_ID`** (the object-engine identity), not on a
business-friendly surrogate. Child rows reference their parent's `INSTANCE_ID`
through a `*_*_ID` column — `SAD_Item.ITM_SGS_ID` → `SAD_General_Segment.INSTANCE_ID`,
`SAD_Tax.TAX_ITM_ID` → `SAD_Item.INSTANCE_ID`, `BOL_TAB.BOL_GEN_ID` →
`GEN_TAB.INSTANCE_ID`.

!!! danger "Symptom"
    You join on a registration number or a reference string and get duplicates or
    misses — those are not unique keys. Or you assume an auto-increment `id` and
    find none.

**Fix** — always traverse via `INSTANCE_ID` and the `*_ID` parent pointers:

```sql
JOIN SAD_Item i ON i.ITM_SGS_ID = g.INSTANCE_ID     -- item → general segment
JOIN SAD_Tax  x ON x.TAX_ITM_ID = i.INSTANCE_ID     -- tax  → item
```

## 2. The general segment is repeated into every item {: #repeated-general-segment }

The single most surprising shape: **AW copies the entire general segment into
every `SAD_Item` row** (and, on the cargo side, into every `BOL_TAB` row). There
is not one header row and N item rows — there are N rows that each carry the full
header *plus* their item.

!!! danger "Symptom"
    Header-level totals come out multiplied by the item count. `sum(SGS_CIF_AMT)`
    over a joined result counts the CIF once per item; a declaration with 3 items
    reports 3× its value.

**Fix** — deduplicate the header on `INSTANCE_ID` before aggregating:

```sql
WITH decl AS (
  SELECT DISTINCT g.INSTANCE_ID, g.SGS_REG_NBR, g.SGS_CIF_AMT
  FROM SAD_General_Segment g
)
SELECT sum(SGS_CIF_AMT) AS total_cif FROM decl;   -- counts each declaration once
```

## 3. HS code is split across `TAR_HSC_NB1..5` {: #hs-split }

The commodity code is stored as **five national-precision fragments** —
`TAR_HSC_NB1`, `TAR_HSC_NB2`, `TAR_HSC_NB3`, `TAR_HSC_NB4`, `TAR_HSC_NB5` — not a
single `hs_code`. The first fragments give the HS-2/HS-4/HS-6 international code;
the later ones carry national precision and may be blank.

!!! danger "Symptom"
    Filtering `WHERE hs_code = '851712'` finds nothing — there is no such column.
    Grouping "by HS" groups by one fragment and merges unrelated commodities.

**Fix** — concatenate the fragments (and be aware trailing fragments can be
empty strings, not `NULL`):

```sql
SELECT i.TAR_HSC_NB1 || i.TAR_HSC_NB2 || i.TAR_HSC_NB3
         || i.TAR_HSC_NB4 || i.TAR_HSC_NB5   AS hs_code
FROM SAD_Item i;
-- prefix match on a 6-digit code:
-- WHERE i.TAR_HSC_NB1 || i.TAR_HSC_NB2 || i.TAR_HSC_NB3 = '851712'
```

## 4. Code and name are stored inline — there is no FK {: #code-name-inline }

AW stores a coded value as **the code and its name together on the same row**
(`GEN_CAR_COD` + `GEN_CAR_NAM`), not as an FK into a lookup table. The reference
table holds the same `_COD` + `_NAM` pair.

!!! danger "Symptom"
    You look for a foreign-key `carrier_id` to join and there isn't one. Or you
    join a reference table on a numeric id and match nothing — the join key is the
    **code string**, and validity is unfiltered so you may match a retired row.

**Fix** — the name is usually already on the row, so *no join is needed*; when
you do join a reference table, join **on the code**, and add the validity
predicate (gotcha 5):

```sql
-- the name is inline — no join required:
SELECT g.GEN_CAR_COD, g.GEN_CAR_NAM FROM GEN_TAB g;

-- when you must join, join on the code + filter validity:
JOIN UNCTYTAB c ON c.CTY_COD = i.ITM_ORG_COD
              AND c.VALID_FROM <= g.SGS_REG_DAT
              AND (c.VALID_TO IS NULL OR c.VALID_TO >= g.SGS_REG_DAT)
```

## 5. Reference tables carry `VALID_FROM` / `VALID_TO` {: #validity }

Every `UN*` reference table keeps **superseded codes** alongside current ones,
distinguished by a **`VALID_FROM`/`VALID_TO`** window. A code is correct for a
declaration only if the declaration's date falls inside it; `VALID_TO IS NULL`
means still current.

!!! danger "Symptom"
    A reference join returns two rows for one code (old + new), silently doubling
    the fact rows. Or a historical declaration resolves against today's re-issued
    code and shows the wrong name/rate.

**Fix** — constrain every reference join to the row valid on the relevant date:

```sql
JOIN UNTAXTAB t ON t.TAX_COD = x.COD
              AND t.VALID_FROM <= g.SGS_REG_DAT
              AND (t.VALID_TO IS NULL OR t.VALID_TO >= g.SGS_REG_DAT)
```

## The compiler handles all five for you

Every fix above is mechanical — which is exactly why the toolbox's
[**query compiler**](../compiler/index.md) bakes them in. You write friendly SQL
against clean logical names; it emits **genuine Sydonia SQL** with the
`INSTANCE_ID` traversal, the `DISTINCT` dedup, the HS `concat`, the code-keyed
reference views and the `VALID_FROM`/`VALID_TO` filter already applied — so you
never re-derive them and never ship a query that silently double-counts.

!!! example "Before / after — logical vs compiled"
    **You write** (against the logical model — no gotchas visible):

    ```sql
    SELECT hs_code, sum(customs_value) AS value
    FROM declaration_item
    GROUP BY hs_code;
    ```

    **The compiler emits** (against the real `SAD_Item` — gotchas 1, 3 handled):

    ```sql
    SELECT concat(i.TAR_HSC_NB1, i.TAR_HSC_NB2, i.TAR_HSC_NB3,
                  i.TAR_HSC_NB4, i.TAR_HSC_NB5)   AS hs_code,
           sum(i.VIT_CIF)                          AS value
    FROM SAD_Item i
    GROUP BY concat(i.TAR_HSC_NB1, i.TAR_HSC_NB2, i.TAR_HSC_NB3,
                    i.TAR_HSC_NB4, i.TAR_HSC_NB5);
    ```

    The mapping that drives this rewrite —
    [`compiler/mappings/asycuda-world.yml`](https://github.com/FrancoisChastel/sydonia-toolkit/blob/master/compiler/mappings/asycuda-world.yml)
    — is the same one whose physical names this section documents, so the docs and
    the tooling never drift apart.

## Quick reference

| # | Gotcha | Symptom | Fix |
|:-:|--------|---------|-----|
| 1 | `INSTANCE_ID` keys | Duplicates/misses on business keys | Traverse via `INSTANCE_ID` + `*_ID` pointers |
| 2 | General segment repeated | Header totals × item count | `DISTINCT` header on `INSTANCE_ID` |
| 3 | HS split `NB1..5` | No `hs_code` column; wrong grouping | Concatenate the 5 fragments |
| 4 | Code + name inline | No FK; join on wrong key | Read inline name, or join on the code |
| 5 | `VALID_FROM`/`VALID_TO` | Double rows; wrong historical code | Filter to the row valid on the date |

## Related

- [Declaration tables](declaration-tables.md) · [Manifest tables](manifest-tables.md) · [Reference tables](reference-tables.md)
- [The query compiler](../compiler/index.md) — the automated way past all five.
- [How faithful is the reconstruction?](../provenance/fit.md) — the source "Aspect" table.
- [Useful queries](../guides/useful-queries.md) — worked queries on the logical model.

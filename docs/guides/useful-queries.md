---
title: Useful queries
description: A curated, growing library of analytical SQL against the customs schema — with a copy-paste format for adding your own.
tags:
  - guides
  - querying
---

# Useful queries

The [querying guide](querying.md) teaches the join paths — the two spines, how
coded columns resolve to `ref_*` names, why totals are derived rather than
stored. This page is the next step: a **growing library of ready analytical
reports** built on those paths, each verified against the seeded sandbox. Add
yours by copying the template.

!!! note "Set the search path once"
    Every table lives in the `asycuda` schema. Run this once per session so bare
    table names resolve. Each fenced block below repeats it to stay
    copy-paste self-contained.
    ```sql
    SET search_path TO asycuda, public;
    ```

!!! tip "These are logical queries — compile them to genuine Sydonia SQL"
    Every query here is written against the friendly **logical model**. To run the
    same SQL on a real ASYCUDA World instance, pipe it through the
    [**query compiler**](../compiler/index.md): it rewrites each into genuine
    Sydonia SQL over the real physical tables. Write friendly, run genuine.

!!! abstract "Built for analytics, ML and selectivity"
    These are more than dashboards. The `risk`, `valuation` and `trader` queries
    below are the **feature-extraction and selectivity-analytics building blocks**
    for a model — effective rates, unit-price outliers, importer discrepancy
    profiles, criterion hit-rates. See the
    [ML risk-engine guide](ml-risk-engine.md) for how these features feed a
    fraud / valuation model and the clearance lanes, and
    [running on a real ASYCUDA World](../platform/running-on-real-asycuda.md) to
    run them on *your own* declarations.

## The entry format

Every query is one **entry** with a fixed shape — keep the headings and their
order exactly:

````markdown
### <Imperative title> { #stable-slug }

**Intent:** one line — what question it answers.
**Tags:** `revenue` · `hs` · `trader` (pick from the vocabulary below)
**Verified:** ✓ against the seeded sandbox

```sql
SET search_path TO asycuda, public;
SELECT …;
```

**How it works:** 2–4 sentences on the join path and any windowing.
**Variations:** optional bullet list of tweaks.
````

### The tag vocabulary

Pick one or more from this closed set; add a new tag here first if you truly
need one, so the vocabulary stays the single source of truth.

| Tag | Use it for |
|-----|------------|
| `revenue` | duty, VAT and fee amounts; fiscal totals and shares |
| `valuation` | customs value, CIF build-up, unit prices, value integrity |
| `risk` | selectivity lanes, criteria, inspection outcomes |
| `trader` | importer, exporter, declarant/broker analytics |
| `manifest` | cargo, bills of lading, write-offs, reconciliation |
| `quality` | data-integrity checks that should return **zero rows** |
| `time` | dwell times, lifecycle durations, throughput over time |
| `suspense` | warehousing, transit, temporary admission, guarantees |

### To add a query

1. Copy the template block above into the right `## ` category (or start a new one).
2. Keep the four bold headings and the fenced `sql` block; write an imperative title and a stable `{ #slug }`.
3. Run it read-only against your sandbox and fix any error before you commit it:
   ```bash
   PGOPTIONS='-c default_transaction_read_only=on -c search_path=asycuda,public' \
     psql -X -d customs_sandbox -c "<your SQL>"
   ```
4. Only then tick **Verified: ✓**. An unverified query does not belong in the library.

!!! tip "Integrity checks are supposed to return nothing"
    A `quality`-tagged query that returns **zero rows** on clean data has
    passed — it found no defects. That is the expected result, not an empty
    report.

---

## Revenue & fiscal

### Effective duty rate by HS chapter { #effective-rate-by-chapter }

**Intent:** what proportion of declared customs value is actually collected as tax, grouped by tariff chapter.
**Tags:** `revenue` · `valuation`
**Verified:** ✓ against the seeded sandbox

```sql
SET search_path TO asycuda, public;
WITH item_tax AS (   -- collapse an item's tax lines to one row first
    SELECT di.id, left(di.hs_code, 2) AS hs_chapter,
           di.customs_value, sum(tl.tax_amount) AS item_tax
    FROM declaration_item di
    JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
    GROUP BY di.id, di.hs_code, di.customs_value
)
SELECT hs_chapter,
       sum(customs_value) AS customs_value,
       sum(item_tax)      AS total_tax,
       round(100.0 * sum(item_tax) / nullif(sum(customs_value), 0), 2) AS effective_rate_pct
FROM item_tax
GROUP BY hs_chapter
ORDER BY effective_rate_pct DESC NULLS LAST;
```

**How it works:** The inner CTE collapses an item's several tax lines to one row *first* — otherwise summing `customs_value` after the tax join double-counts the value once per tax line. Only then is value and tax rolled up per chapter and divided.
**Variations:** group by `di.hs_id` + join `ref_hs_tariff` for the full code; filter `WHERE tt.code = 'IMP'` for a duty-only rate.

### Rank revenue concentration with a running share { #revenue-concentration }

**Intent:** which HS chapters carry the revenue, and how few of them make up most of it (Pareto view).
**Tags:** `revenue` · `hs`
**Verified:** ✓ against the seeded sandbox

```sql
SET search_path TO asycuda, public;
WITH chapter_rev AS (
    SELECT left(di.hs_code, 2) AS hs_chapter,
           sum(tl.tax_amount)  AS revenue
    FROM declaration_item di
    JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
    GROUP BY 1
)
SELECT hs_chapter,
       revenue,
       round(100.0 * revenue / sum(revenue) OVER (), 1)          AS pct_of_total,
       round(100.0 * sum(revenue) OVER (ORDER BY revenue DESC)
                   / sum(revenue) OVER (), 1)                     AS running_pct
FROM chapter_rev
ORDER BY revenue DESC;
```

**How it works:** Two window frames over the same result: `SUM() OVER ()` gives the grand total for each row's share, and `SUM() OVER (ORDER BY revenue DESC)` accumulates a running total down the ranking, reaching 100 at the last row.
**Variations:** swap the chapter expression for `d.consignee_id` (join `trader`) to concentrate by importer; wrap with `WHERE running_pct <= 80` for the vital-few chapters.

### Split duty, VAT and other taxes per office { #duty-vat-split }

**Intent:** how each customs office's collection breaks down between import duty, VAT and everything else.
**Tags:** `revenue`
**Verified:** ✓ against the seeded sandbox

```sql
SET search_path TO asycuda, public;
SELECT off.office_code,
       off.name                                                       AS office,
       sum(tl.tax_amount) FILTER (WHERE tt.code = 'IMP')              AS import_duty,
       sum(tl.tax_amount) FILTER (WHERE tt.code = 'VAT')              AS vat,
       sum(tl.tax_amount) FILTER (WHERE tt.code NOT IN ('IMP','VAT')) AS other_taxes,
       round(100.0 * sum(tl.tax_amount) FILTER (WHERE tt.code = 'VAT')
                   / nullif(sum(tl.tax_amount), 0), 1)                AS vat_share_pct
FROM declaration d
JOIN ref_customs_office off  ON off.id = d.office_id
JOIN declaration_item di     ON di.declaration_id = d.id
JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
JOIN ref_tax_type tt         ON tt.id = tl.tax_type_id
GROUP BY off.office_code, off.name
ORDER BY off.office_code;
```

**How it works:** `FILTER (WHERE …)` turns one pass over the tax lines into several conditional sums, so duty, VAT and residual taxes land in separate columns without a self-join. Codes come from `ref_tax_type`.
**Variations:** add `d.registration_date` to the grouping for a monthly breakdown per office.

## Valuation quality

### Flag unit-price outliers against the per-HS median { #unit-price-outliers }

**Intent:** which item lines are priced far from the typical value-per-kilo for their HS code — a classic under-valuation signal.
**Tags:** `valuation` · `risk`
**Verified:** ✓ against the seeded sandbox

```sql
SET search_path TO asycuda, public;
WITH unit AS (
    SELECT di.id, di.hs_code,
           (di.customs_value / nullif(di.net_mass, 0))::numeric AS unit_price
    FROM declaration_item di
    WHERE di.net_mass > 0 AND di.customs_value IS NOT NULL
),
hs_median AS (   -- percentile_cont is an ordered-set aggregate, not a window fn
    SELECT hs_code,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY unit_price)::numeric AS median_unit_price
    FROM unit GROUP BY hs_code
)
SELECT u.hs_code,
       round(u.unit_price, 4)        AS unit_price,
       round(m.median_unit_price, 4) AS hs_median,
       round(100.0 * (u.unit_price - m.median_unit_price)
                   / nullif(m.median_unit_price, 0), 1) AS deviation_pct
FROM unit u
JOIN hs_median m ON m.hs_code = u.hs_code
ORDER BY abs(u.unit_price - m.median_unit_price) DESC;
```

**How it works:** The first CTE derives a value-per-kilo per item; the second computes the median per HS code. `percentile_cont` is an ordered-set aggregate — it cannot be a window function, so the median is grouped in its own CTE and joined back. Rows are ordered by absolute deviation, largest first.
**Variations:** filter `WHERE abs(deviation_pct) > 40` for strong outliers only; group the median by `left(hs_code, 4)` (heading) for thin datasets.

### Reconcile item customs value against the valuation note { #value-vs-valuation-note }

**Intent:** find item lines whose declared `customs_value` disagrees with the per-item CIF built up in the valuation note.
**Tags:** `valuation` · `quality`
**Verified:** ✓ against the seeded sandbox — returns zero rows on clean data

```sql
SET search_path TO asycuda, public;
SELECT d.registration_number, di.item_number, di.hs_code,
       di.customs_value, ivn.item_cif,
       (di.customs_value - ivn.item_cif) AS difference
FROM declaration_item di
JOIN declaration d       ON d.id = di.declaration_id
JOIN item_value_note ivn ON ivn.declaration_item_id = di.id
WHERE di.customs_value IS DISTINCT FROM ivn.item_cif
ORDER BY abs(di.customs_value - ivn.item_cif) DESC;
```

**How it works:** `item_value_note.item_cif` is the freight-and-insurance-apportioned value that *should* equal the item's `customs_value`. `IS DISTINCT FROM` treats NULLs safely, so a missing value on either side surfaces rather than hides. Any row returned is an integrity break to investigate.

## Risk & selectivity

### Measure criterion hit-rate and discrepancy rate { #criterion-hit-rate }

**Intent:** for each risk criterion, how often it fires, how often that leads to inspection, and how often inspection finds a discrepancy.
**Tags:** `risk`
**Verified:** ✓ against the seeded sandbox

```sql
SET search_path TO asycuda, public;
SELECT rc.code                                               AS criterion,
       rc.name,
       count(sr.id)                                          AS times_triggered,
       count(ia.id)                                          AS inspections,
       count(ia.id) FILTER (WHERE ia.result = 'discrepancy') AS discrepancies,
       round(100.0 * count(ia.id) FILTER (WHERE ia.result = 'discrepancy')
                   / nullif(count(ia.id), 0), 1)             AS discrepancy_rate_pct
FROM risk_criterion rc
LEFT JOIN selectivity_result sr ON sr.criterion_id = rc.id
LEFT JOIN inspection_act ia     ON ia.declaration_id = sr.declaration_id
GROUP BY rc.code, rc.name
ORDER BY discrepancy_rate_pct DESC NULLS LAST, times_triggered DESC;
```

**How it works:** Walks `risk_criterion → selectivity_result` (each firing) then to the `inspection_act` of the same declaration; `LEFT JOIN` keeps criteria that never fired. A high discrepancy rate on a frequently-firing criterion is well targeted; one that fires often but finds nothing is a candidate to retire.

### Profile importers by discrepancy history { #trader-discrepancy-profile }

**Intent:** which importers have a track record of inspection discrepancies — a signal to feed back into risk profiling.
**Tags:** `risk` · `trader`
**Verified:** ✓ against the seeded sandbox

```sql
SET search_path TO asycuda, public;
SELECT tr.tin,
       tr.name                                               AS importer,
       count(DISTINCT d.id)                                  AS declarations,
       count(DISTINCT ia.declaration_id)                     AS inspected,
       count(ia.id) FILTER (WHERE ia.result = 'discrepancy') AS discrepancies,
       round(100.0 * count(ia.id) FILTER (WHERE ia.result = 'discrepancy')
                   / nullif(count(ia.id), 0), 1)             AS discrepancy_rate_pct
FROM declaration d
JOIN trader tr              ON tr.id = d.consignee_id
LEFT JOIN inspection_act ia ON ia.declaration_id = d.id
GROUP BY tr.tin, tr.name
HAVING count(ia.id) > 0
ORDER BY discrepancy_rate_pct DESC, declarations DESC;
```

**How it works:** Joins each declaration to its consignee (`consignee_id → trader`) and to any inspection acts. `HAVING count(ia.id) > 0` restricts to importers actually inspected, so the rate is meaningful; the sort brings the worst offenders to the top.

## Trader analytics

### Build the importer league table { #importer-league-table }

**Intent:** rank importers by volume, total customs value and total tax paid.
**Tags:** `trader` · `revenue`
**Verified:** ✓ against the seeded sandbox

```sql
SET search_path TO asycuda, public;
WITH decl_tax AS (
    SELECT di.declaration_id, sum(tl.tax_amount) AS decl_tax
    FROM declaration_item di
    JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
    GROUP BY di.declaration_id
)
SELECT tr.tin,
       tr.name                AS importer,
       count(DISTINCT d.id)   AS declarations,
       sum(d.total_cif_value) AS total_cif,
       sum(dt.decl_tax)       AS total_tax
FROM declaration d
JOIN trader tr        ON tr.id = d.consignee_id
LEFT JOIN decl_tax dt ON dt.declaration_id = d.id
GROUP BY tr.tin, tr.name
ORDER BY total_tax DESC NULLS LAST;
```

**How it works:** Tax is pre-aggregated to one row per declaration in the CTE *before* the join, so summing per importer never multiplies by the item count. `total_cif_value` is the stored declaration total, safe to sum directly.
**Variations:** swap `d.consignee_id` for `d.exporter_id` to rank exporters instead.

### Rank broker (declarant) activity { #declarant-activity }

**Intent:** how much clearance work each broker handles, and across how many distinct importers.
**Tags:** `trader`
**Verified:** ✓ against the seeded sandbox

```sql
SET search_path TO asycuda, public;
SELECT br.tin,
       br.name                        AS declarant,
       count(*)                       AS declarations_lodged,
       count(DISTINCT d.consignee_id) AS distinct_importers,
       sum(d.total_cif_value)         AS total_cif_handled
FROM declaration d
JOIN trader br ON br.id = d.declarant_id
GROUP BY br.tin, br.name
ORDER BY declarations_lodged DESC;
```

**How it works:** The declarant (SAD box 14) is a `trader` in its own right, referenced by `declaration.declarant_id`. Counting distinct `consignee_id` shows whether a broker serves one client or many.

## Manifest reconciliation

### Reconcile manifested against written-off packages { #manifest-writeoff-reconciliation }

**Intent:** per bill of lading, compare the packages the carrier manifested with the packages actually written off on declarations — surfacing under- or over-declaration.
**Tags:** `manifest` · `quality`
**Verified:** ✓ against the seeded sandbox

```sql
SET search_path TO asycuda, public;
WITH manifested AS (
    SELECT bl.id AS bl_id, bl.bl_reference,
           sum(ci.number_of_packages) AS manifested_packages
    FROM bill_of_lading bl
    JOIN manifest_cargo_item ci ON ci.bl_id = bl.id
    GROUP BY bl.id, bl.bl_reference
),
written_off AS (
    SELECT pd.bl_id, sum(pd.written_off_packages) AS written_off_packages
    FROM declaration_previous_document pd
    WHERE pd.bl_id IS NOT NULL GROUP BY pd.bl_id
)
SELECT m.bl_reference,
       m.manifested_packages,
       coalesce(w.written_off_packages, 0)                         AS written_off_packages,
       m.manifested_packages - coalesce(w.written_off_packages, 0) AS remaining_packages
FROM manifested m
LEFT JOIN written_off w ON w.bl_id = m.bl_id
ORDER BY remaining_packages DESC;
```

**How it works:** One CTE totals the cargo lines per B/L; the other totals what declarations wrote off against it via `declaration_previous_document` (SAD box 40). `remaining_packages` above zero is cargo not yet cleared; below zero means more was declared than manifested — an anomaly.

## Lifecycle timing

### Measure dwell time between status transitions { #status-dwell-time }

**Intent:** how long a declaration sits at each stage — registered → assessed → paid → released.
**Tags:** `time`
**Verified:** ✓ against the seeded sandbox

```sql
SET search_path TO asycuda, public;
WITH trail AS (
    SELECT d.registration_number, st.code AS status, h.changed_at,
           lead(st.code)      OVER w AS next_status,
           lead(h.changed_at) OVER w AS next_changed_at
    FROM declaration_status_history h
    JOIN declaration d             ON d.id = h.declaration_id
    JOIN ref_declaration_status st ON st.id = h.status_id
    WINDOW w AS (PARTITION BY h.declaration_id ORDER BY h.changed_at)
)
SELECT registration_number,
       status || ' -> ' || next_status AS transition,
       changed_at, next_changed_at - changed_at AS dwell
FROM trail
WHERE next_status IS NOT NULL
ORDER BY registration_number, changed_at;
```

**How it works:** `lead()` looks one row ahead within each declaration's history (ordered by `changed_at`), so every row knows its successor status and time. The interval between them is the dwell at the current stage; the final status has no successor and drops out.
**Variations:** aggregate `avg(next_changed_at - changed_at)` grouped by the transition for a mean dwell per stage across all declarations.

## Data quality

### List item lines carrying no tax { #items-without-tax }

**Intent:** find declaration items with no tax line at all — usually a data-entry gap rather than a genuine zero-rating.
**Tags:** `quality`
**Verified:** ✓ against the seeded sandbox — returns zero rows on clean data

```sql
SET search_path TO asycuda, public;
SELECT d.registration_number, di.item_number, di.hs_code, di.customs_value
FROM declaration_item di
JOIN declaration d ON d.id = di.declaration_id
WHERE NOT EXISTS (
    SELECT 1 FROM declaration_tax_line tl WHERE tl.declaration_item_id = di.id
)
ORDER BY d.registration_number, di.item_number;
```

**How it works:** An anti-join with `NOT EXISTS` keeps only items with no matching tax line. Genuine relief should still show a zero-amount line with an exemption code, so a truly empty item is worth a second look.

### Catch assessed tax that does not match the receipt { #assessed-vs-receipted }

**Intent:** flag declarations where the sum of tax lines differs from the amount actually receipted.
**Tags:** `quality` · `revenue`
**Verified:** ✓ against the seeded sandbox — returns zero rows on clean data

```sql
SET search_path TO asycuda, public;
SELECT d.registration_number, assessed.total_tax,
       r.total_amount                                   AS receipted,
       assessed.total_tax - coalesce(r.total_amount, 0) AS variance
FROM declaration d
JOIN LATERAL (
    SELECT sum(tl.tax_amount) AS total_tax
    FROM declaration_item di
    JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
    WHERE di.declaration_id = d.id
) assessed ON true
LEFT JOIN payment p ON p.declaration_id = d.id
LEFT JOIN receipt r ON r.payment_id = p.id
WHERE assessed.total_tax IS DISTINCT FROM coalesce(r.total_amount, 0)
ORDER BY abs(assessed.total_tax - coalesce(r.total_amount, 0)) DESC;
```

**How it works:** A `LATERAL` subquery totals the tax per declaration; the payment and receipt are joined in. This is the sibling of the querying guide's assessed-vs-paid check, but *filtered* to keep only the mismatches — a focused exception report rather than a full reconciliation.

### Find released declarations missing a required inspection act { #released-without-inspection }

**Intent:** released declarations on an exam-requiring lane that have no inspection act on file — a control gap.
**Tags:** `quality` · `risk`
**Verified:** ✓ against the seeded sandbox — returns zero rows on clean data

```sql
SET search_path TO asycuda, public;
SELECT d.registration_number, lane.code AS lane, st.code AS status
FROM declaration d
JOIN ref_selectivity_lane lane ON lane.id = d.selectivity_lane_id
JOIN ref_declaration_status st ON st.id = d.status_id
WHERE lane.requires_exam
  AND st.code = 'released'
  AND NOT EXISTS (
      SELECT 1 FROM inspection_act ia WHERE ia.declaration_id = d.id
  )
ORDER BY d.registration_number;
```

**How it works:** If a lane's `requires_exam` is true, release should be preceded by an `inspection_act`. The `NOT EXISTS` anti-join returns any declaration that reached `released` without one — a procedural breach worth auditing.

---

## Run these on a real ASYCUDA World system

Everything here targets the toolbox's normalised `asycuda` schema, not the real
ASYCUDA World physical tables. To point the same SQL at a live system, run it
through the compatibility-view adapter in
[running on real ASYCUDA](../platform/running-on-real-asycuda.md) — the views
expose these table and column names over the real store, so the queries above
run unchanged.

## Test before you trust

Before adding a query here — or running one you did not write against a
production database — validate it. The [`customs-query`](../skills/index.md)
skill tests SQL through the customs-query-tester MCP, and the bundled
`skills/customs-query/scripts/test_query.sh` does the same from the shell. Both
are **privacy-preserving**: they check the query against schema metadata and a
read-only plan, never returning row data — safe against databases holding real
customs declarations.

---
title: Querying the model
description: The join paths that matter, plus an analytics cookbook.
tags:
  - guides
  - querying
---

# Querying the model

The model is normalised, so coded values are foreign keys and totals are derived
by query. This page is the cookbook of join paths you will reach for.

!!! note "Set the search path first"
    Every table is in the `asycuda` schema. Run this once per session (or
    `ALTER DATABASE … SET search_path`) so you can use bare names:
    ```sql
    SET search_path TO asycuda, public;
    ```

## The two spines

Almost every query walks one of two chains:

```text
manifest → bill_of_lading → container / manifest_cargo_item        (cargo spine)
declaration → declaration_item → declaration_tax_line              (declaration spine)
                              ↘ item_value_note (per-item CIF)
```

## Assemble a full declaration

Resolve the coded foreign keys into human-readable columns:

```sql
SELECT d.registration_serial || ' ' || d.registration_number AS reg,
       ty.code   AS type,
       off.name  AS office,
       exp.name  AS exporter,
       imp.name  AS consignee,
       st.code   AS status,
       lane.code AS lane,
       d.total_cif_value
FROM declaration d
JOIN ref_declaration_type   ty   ON ty.id   = d.declaration_type_id
JOIN ref_customs_office     off  ON off.id  = d.office_id
JOIN trader                 exp  ON exp.id  = d.exporter_id
JOIN trader                 imp  ON imp.id  = d.consignee_id
JOIN ref_declaration_status st   ON st.id   = d.status_id
JOIN ref_selectivity_lane   lane ON lane.id = d.selectivity_lane_id
WHERE d.trader_reference = 'REF-2026-0001';
```

## Items with their taxes

```sql
SELECT di.item_number,
       di.hs_code,
       di.customs_value,
       jsonb_object_agg(tt.code, tl.tax_amount) AS taxes,
       sum(tl.tax_amount)                       AS total_tax
FROM declaration_item di
JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
JOIN ref_tax_type tt         ON tt.id = tl.tax_type_id
WHERE di.declaration_id = (SELECT id FROM declaration WHERE trader_reference='REF-2026-0001')
GROUP BY di.item_number, di.hs_code, di.customs_value
ORDER BY di.item_number;
```

## Cargo spine — manifest to goods lines

```sql
SELECT m.voyage_number,
       bl.bl_reference,
       ctn.ctn_reference,
       ci.hs_code,
       ci.goods_description,
       ci.number_of_packages
FROM manifest m
JOIN bill_of_lading bl        ON bl.manifest_id = m.id
LEFT JOIN container ctn       ON ctn.bl_id = bl.id
JOIN manifest_cargo_item ci   ON ci.bl_id = bl.id
WHERE m.voyage_number = 'V2026-042'
ORDER BY bl.line_number, ci.line_number;
```

## Assessed vs paid reconciliation

The single most useful integrity query — do the taxes, the payment and the
receipt agree?

```sql
SELECT d.registration_number,
       assessed.total_tax,
       p.amount        AS paid,
       r.total_amount  AS receipted,
       assessed.total_tax = coalesce(r.total_amount, 0) AS balanced
FROM declaration d
JOIN LATERAL (
    SELECT sum(tl.tax_amount) AS total_tax
    FROM declaration_item di
    JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
    WHERE di.declaration_id = d.id
) assessed ON true
LEFT JOIN payment p ON p.declaration_id = d.id
LEFT JOIN receipt r ON r.payment_id = p.id;
```

## Revenue by tax type

```sql
SELECT tt.code AS tax,
       count(*)              AS lines,
       sum(tl.tax_amount)    AS revenue
FROM declaration_tax_line tl
JOIN ref_tax_type tt ON tt.id = tl.tax_type_id
GROUP BY tt.code
ORDER BY revenue DESC;
```

## Revenue by HS chapter

```sql
SELECT left(di.hs_code, 2) AS hs_chapter,
       sum(di.customs_value) AS declared_value,
       sum(tl.tax_amount)    AS revenue
FROM declaration_item di
LEFT JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
GROUP BY 1
ORDER BY revenue DESC NULLS LAST;
```

## Selectivity throughput

```sql
SELECT lane.code AS lane,
       count(*)                                       AS declarations,
       count(*) FILTER (WHERE ia.result = 'conform')  AS conform,
       round(100.0 * count(ia.id) / count(*), 1)      AS pct_inspected
FROM declaration d
JOIN ref_selectivity_lane lane ON lane.id = d.selectivity_lane_id
LEFT JOIN inspection_act ia    ON ia.declaration_id = d.id
GROUP BY lane.code
ORDER BY lane.code;
```

## Trace a write-off to the manifest

Which manifest bill of lading did each declared item come from?

```sql
SELECT d.registration_number,
       di.item_number,
       di.hs_code,
       bl.bl_reference,
       pd.written_off_packages,
       pd.written_off_mass
FROM declaration_previous_document pd
JOIN declaration d       ON d.id  = pd.declaration_id
JOIN declaration_item di ON di.id = pd.declaration_item_id
JOIN bill_of_lading bl   ON bl.id = pd.bl_id
ORDER BY d.registration_number, di.item_number;
```

## Goods still in a warehouse

```sql
SELECT w.code AS warehouse, we.entry_date, we.packages, we.gross_mass
FROM warehouse_entry we
JOIN ref_warehouse w        ON w.id = we.warehouse_id
LEFT JOIN warehouse_exit wx ON wx.warehouse_entry_id = we.id
WHERE wx.id IS NULL
ORDER BY we.entry_date;
```

## Save the common joins as views

If you query the model a lot, wrap the resolved joins in a view:

```sql
CREATE VIEW asycuda.v_declaration_summary AS
SELECT d.id,
       d.registration_serial || ' ' || d.registration_number AS reg,
       ty.code AS type, st.code AS status, lane.code AS lane,
       d.total_items, d.total_cif_value
FROM declaration d
JOIN ref_declaration_type   ty   ON ty.id   = d.declaration_type_id
JOIN ref_declaration_status st   ON st.id   = d.status_id
JOIN ref_selectivity_lane   lane ON lane.id = d.selectivity_lane_id;
```

!!! tip "Let an Agent Skill write the joins"
    The [`customs-query`](../skills/index.md) skill knows these join paths and the
    `search_path` requirement, so you can ask for a report in plain English and get
    a correct query back.

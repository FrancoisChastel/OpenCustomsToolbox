-- =====================================================================
-- cookbook.sql — canonical queries against the Open Customs Toolbox model.
-- Adapt the closest query to the user's question. All assume:
SET search_path TO asycuda, public;
-- =====================================================================

-- 1 · Assemble a full declaration (resolve coded FKs to names) -----------
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

-- 2 · Items with their taxes (one row per line, taxes rolled up) ---------
SELECT di.item_number,
       di.hs_code,
       di.customs_value,
       jsonb_object_agg(tt.code, tl.tax_amount) AS taxes,
       sum(tl.tax_amount)                       AS total_tax
FROM declaration_item di
JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
JOIN ref_tax_type tt         ON tt.id = tl.tax_type_id
WHERE di.declaration_id =
      (SELECT id FROM declaration WHERE trader_reference = 'REF-2026-0001')
GROUP BY di.item_number, di.hs_code, di.customs_value
ORDER BY di.item_number;

-- 3 · Cargo spine: manifest → B/L → container → goods lines --------------
SELECT m.voyage_number, bl.bl_reference, ctn.ctn_reference,
       ci.hs_code, ci.goods_description, ci.number_of_packages
FROM manifest m
JOIN bill_of_lading bl      ON bl.manifest_id = m.id
LEFT JOIN container ctn     ON ctn.bl_id = bl.id
JOIN manifest_cargo_item ci ON ci.bl_id = bl.id
WHERE m.voyage_number = 'V2026-042'
ORDER BY bl.line_number, ci.line_number;

-- 4 · Assessed vs paid vs receipted (integrity check) --------------------
SELECT d.registration_number,
       assessed.total_tax,
       p.amount       AS paid,
       r.total_amount AS receipted,
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

-- 5 · Revenue by tax type ------------------------------------------------
SELECT tt.code AS tax, count(*) AS lines, sum(tl.tax_amount) AS revenue
FROM declaration_tax_line tl
JOIN ref_tax_type tt ON tt.id = tl.tax_type_id
GROUP BY tt.code
ORDER BY revenue DESC;

-- 6 · Revenue and declared value by HS chapter ---------------------------
SELECT left(di.hs_code, 2) AS hs_chapter,
       sum(di.customs_value) AS declared_value,
       sum(tl.tax_amount)    AS revenue
FROM declaration_item di
LEFT JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
GROUP BY 1
ORDER BY revenue DESC NULLS LAST;

-- 7 · Selectivity throughput ---------------------------------------------
SELECT lane.code AS lane,
       count(*)                                      AS declarations,
       count(*) FILTER (WHERE ia.result = 'conform') AS conform,
       round(100.0 * count(ia.id) / count(*), 1)     AS pct_inspected
FROM declaration d
JOIN ref_selectivity_lane lane ON lane.id = d.selectivity_lane_id
LEFT JOIN inspection_act ia    ON ia.declaration_id = d.id
GROUP BY lane.code
ORDER BY lane.code;

-- 8 · Trace item write-offs back to the manifest B/L (SAD box 40) --------
SELECT d.registration_number, di.item_number, di.hs_code,
       bl.bl_reference, pd.written_off_packages, pd.written_off_mass
FROM declaration_previous_document pd
JOIN declaration d       ON d.id  = pd.declaration_id
JOIN declaration_item di ON di.id = pd.declaration_item_id
JOIN bill_of_lading bl   ON bl.id = pd.bl_id
ORDER BY d.registration_number, di.item_number;

-- 9 · Goods still in a warehouse (entered, not yet exited) ---------------
SELECT w.code AS warehouse, we.entry_date, we.packages, we.gross_mass
FROM warehouse_entry we
JOIN ref_warehouse w        ON w.id = we.warehouse_id
LEFT JOIN warehouse_exit wx ON wx.warehouse_entry_id = we.id
WHERE wx.id IS NULL
ORDER BY we.entry_date;

-- 10 · Lifecycle trail of a declaration ----------------------------------
SELECT st.sort_order, st.code, h.changed_at, u.login_name AS changed_by, h.note
FROM declaration_status_history h
JOIN ref_declaration_status st ON st.id = h.status_id
LEFT JOIN sys_user u           ON u.id = h.changed_by
JOIN declaration d             ON d.id = h.declaration_id
WHERE d.trader_reference = 'REF-2026-0001'
ORDER BY h.changed_at;

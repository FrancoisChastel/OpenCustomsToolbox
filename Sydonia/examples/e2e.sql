-- =====================================================================
-- e2e.sql — end-to-end worked example proving referential integrity.
-- Flow (GOAL §1 done-condition 1):
--   manifest -> declaration with 2 items -> valuation note -> tax lines -> release
-- Load AFTER schema/asycuda.sql and schema/seed_reference.sql.
-- Every row uses natural-key subselects so the script is order-independent
-- and self-documenting. Wrapped in one transaction; a final SELECT block
-- prints the assembled declaration for a visual sanity check.
-- =====================================================================

BEGIN;
SET search_path TO asycuda, public;

-- ---- 0. Parties (economic operators) ------------------------------------
INSERT INTO trader (tin, name, address, country_id) VALUES
    ('CARR001','Pacific Ocean Lines',   '1 Harbour Rd, Singapore', (SELECT id FROM ref_country WHERE iso_alpha2='SG')),
    ('AGT001', 'Island Shipping Agency','Pohnpei Port',            (SELECT id FROM ref_country WHERE iso_alpha2='FM')),
    ('EXP001', 'Shenzhen Electronics Co','Shenzhen, China',        (SELECT id FROM ref_country WHERE iso_alpha2='CN')),
    ('IMP001', 'Pohnpei Trading Ltd',    'Kolonia, Pohnpei',       (SELECT id FROM ref_country WHERE iso_alpha2='FM')),
    ('BRK001', 'FSM Customs Brokers',    'Kolonia, Pohnpei',       (SELECT id FROM ref_country WHERE iso_alpha2='FM'));

INSERT INTO trader_role (trader_id, role) VALUES
    ((SELECT id FROM trader WHERE tin='CARR001'),'carrier'),
    ((SELECT id FROM trader WHERE tin='AGT001'),'agent'),
    ((SELECT id FROM trader WHERE tin='EXP001'),'exporter'),
    ((SELECT id FROM trader WHERE tin='IMP001'),'importer'),
    ((SELECT id FROM trader WHERE tin='IMP001'),'consignee'),
    ((SELECT id FROM trader WHERE tin='BRK001'),'broker');

INSERT INTO sys_user (login_name, full_name, trader_id, office_id) VALUES
    ('broker.jdoe','J. Doe (broker)', (SELECT id FROM trader WHERE tin='BRK001'), NULL),
    ('cust.aofficer','A. Officer (customs)', NULL, (SELECT id FROM ref_customs_office WHERE office_code='FMPNI'));

-- ---- 1. Manifest (Shanghai -> Pohnpei, sea) -----------------------------
INSERT INTO manifest
    (office_id, manifest_year, registration_number, voyage_number, transport_mode_id,
     identity_of_transport, nationality_id, registration_ref, master_name,
     carrier_id, shipping_agent_id, place_departure_id, place_destination_id,
     date_of_departure, date_of_arrival, total_bols, total_packages, total_containers,
     total_gross_mass, status_id)
VALUES
    ((SELECT id FROM ref_customs_office WHERE office_code='FMPNI'),
     2026, 12, 'V2026-042',
     (SELECT id FROM ref_transport_mode WHERE code='1'),
     'MV Pacific Star', (SELECT id FROM ref_country WHERE iso_alpha2='SG'),
     'IMO9241061', 'Capt. R. Marlowe',
     (SELECT id FROM trader WHERE tin='CARR001'),
     (SELECT id FROM trader WHERE tin='AGT001'),
     (SELECT id FROM ref_location WHERE unlocode='CNSHA'),
     (SELECT id FROM ref_location WHERE unlocode='FMPNI'),
     DATE '2026-06-20', DATE '2026-07-05', 1, 250, 1, 4200.000,
     (SELECT id FROM ref_manifest_status WHERE code='registered'));

INSERT INTO manifest_status_history (manifest_id, status_id, changed_by, note) VALUES
    ((SELECT id FROM manifest WHERE voyage_number='V2026-042'),
     (SELECT id FROM ref_manifest_status WHERE code='registered'),
     (SELECT id FROM sys_user WHERE login_name='cust.aofficer'), 'Manifest registered on arrival');

-- Bill of lading (import consignment) + container + 2 cargo lines
INSERT INTO bill_of_lading
    (manifest_id, line_number, bl_reference, bl_nature_id, bl_type_code, is_master,
     exporter_id, consignee_id, place_loading_id, place_unloading_id,
     number_of_packages, package_type_id, gross_mass, goods_description,
     freight_indicator, freight_value, freight_currency_id, customs_value, insurance_value)
VALUES
    ((SELECT id FROM manifest WHERE voyage_number='V2026-042'),
     1, 'POL-BL-88231',
     (SELECT id FROM ref_bl_nature WHERE code='23'), 'HBL', false,
     (SELECT id FROM trader WHERE tin='EXP001'),
     (SELECT id FROM trader WHERE tin='IMP001'),
     (SELECT id FROM ref_location WHERE unlocode='CNSHA'),
     (SELECT id FROM ref_location WHERE unlocode='FMPNI'),
     250, (SELECT id FROM ref_package_type WHERE code='CT'), 4200.000,
     'Consumer electronics and apparel', 'PP', 3000.0000,
     (SELECT id FROM ref_currency WHERE iso_code='USD'), 60000.0000, 300.0000);

INSERT INTO container (bl_id, ctn_reference, container_type_id, number_of_packages,
                       empty_full, seal1, empty_weight, goods_weight, volume_m3, goods_description)
VALUES
    ((SELECT id FROM bill_of_lading WHERE bl_reference='POL-BL-88231'),
     'OTEU1223808', (SELECT id FROM ref_container_type WHERE code='42G1'),
     250, 'full', 'SEAL55231', 3800.000, 4200.000, 67.000, 'Electronics and apparel');

INSERT INTO manifest_cargo_item (bl_id, line_number, hs_code, goods_description,
                                 number_of_packages, package_type_id, gross_mass, container_id)
VALUES
    ((SELECT id FROM bill_of_lading WHERE bl_reference='POL-BL-88231'), 1, '851712',
     'Mobile telephones', 100, (SELECT id FROM ref_package_type WHERE code='CT'), 1800.000,
     (SELECT id FROM container WHERE ctn_reference='OTEU1223808')),
    ((SELECT id FROM bill_of_lading WHERE bl_reference='POL-BL-88231'), 2, '610910',
     'Cotton T-shirts', 150, (SELECT id FROM ref_package_type WHERE code='CT'), 2400.000,
     (SELECT id FROM container WHERE ctn_reference='OTEU1223808'));

-- ---- 2. Declaration (IM4 import for home use) ---------------------------
INSERT INTO declaration
    (office_id, declaration_type_id, cpc_id, registration_serial, registration_number,
     registration_date, trader_reference, exporter_id, consignee_id, declarant_id, financial_id,
     country_export_id, country_origin_id, country_destination_id, country_last_consign_id,
     trading_country_id, incoterm_id, delivery_place, transport_mode_border_id,
     place_of_discharge_id, total_items, total_packages, currency_id, total_invoice_amount,
     exchange_rate, total_freight, total_insurance, total_cif_value,
     selectivity_lane_id, status_id, assessment_number, assessment_date, manifest_id, created_by)
VALUES
    ((SELECT id FROM ref_customs_office WHERE office_code='FMPNI'),
     (SELECT id FROM ref_declaration_type WHERE code='IM4'),
     (SELECT id FROM ref_cpc_regime WHERE cpc_code='4000'),
     'C', 427, DATE '2026-07-06', 'REF-2026-0001',
     (SELECT id FROM trader WHERE tin='EXP001'),
     (SELECT id FROM trader WHERE tin='IMP001'),
     (SELECT id FROM trader WHERE tin='BRK001'),
     (SELECT id FROM trader WHERE tin='IMP001'),
     (SELECT id FROM ref_country WHERE iso_alpha2='CN'),
     (SELECT id FROM ref_country WHERE iso_alpha2='CN'),
     (SELECT id FROM ref_country WHERE iso_alpha2='FM'),
     (SELECT id FROM ref_country WHERE iso_alpha2='CN'),
     (SELECT id FROM ref_country WHERE iso_alpha2='CN'),
     (SELECT id FROM ref_incoterm WHERE code='CIF'),
     'Pohnpei', (SELECT id FROM ref_transport_mode WHERE code='1'),
     (SELECT id FROM ref_location WHERE unlocode='FMPNI'),
     2, 250, (SELECT id FROM ref_currency WHERE iso_code='USD'), 60000.0000,
     1.000000, 3000.0000, 300.0000, 63300.0000,
     (SELECT id FROM ref_selectivity_lane WHERE code='RED'),
     (SELECT id FROM ref_declaration_status WHERE code='stored'),
     NULL, NULL,
     (SELECT id FROM manifest WHERE voyage_number='V2026-042'),
     (SELECT id FROM sys_user WHERE login_name='broker.jdoe'));

-- Item 1: mobile phones (HS 851712), FOB 40000
INSERT INTO declaration_item
    (declaration_id, item_number, hs_id, hs_code, goods_description, country_origin_id,
     cpc_id, national_procedure, number_of_packages, package_type_id, marks_and_numbers,
     container_reference, gross_mass, net_mass, supplementary_qty, supplementary_uom_id,
     item_price, valuation_method_code, statistical_value, customs_value)
VALUES
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     1, (SELECT id FROM ref_hs_tariff WHERE hs_code='851712'), '851712', 'Mobile telephones',
     (SELECT id FROM ref_country WHERE iso_alpha2='CN'),
     (SELECT id FROM ref_cpc_regime WHERE cpc_code='4000'), '000',
     100, (SELECT id FROM ref_package_type WHERE code='CT'), 'PTL/1-100',
     'OTEU1223808', 1800.000, 1650.000, 5000, (SELECT id FROM ref_unit_of_measure WHERE code='NMB'),
     40000.0000, '1', 42200.0000, 42200.0000);

-- Item 2: cotton T-shirts (HS 610910), FOB 20000
INSERT INTO declaration_item
    (declaration_id, item_number, hs_id, hs_code, goods_description, country_origin_id,
     cpc_id, national_procedure, number_of_packages, package_type_id, marks_and_numbers,
     container_reference, gross_mass, net_mass, supplementary_qty, supplementary_uom_id,
     item_price, valuation_method_code, statistical_value, customs_value)
VALUES
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     2, (SELECT id FROM ref_hs_tariff WHERE hs_code='610910'), '610910', 'Cotton T-shirts',
     (SELECT id FROM ref_country WHERE iso_alpha2='CN'),
     (SELECT id FROM ref_cpc_regime WHERE cpc_code='4000'), '000',
     150, (SELECT id FROM ref_package_type WHERE code='CT'), 'PTL/101-250',
     'OTEU1223808', 2400.000, 2250.000, 10000, (SELECT id FROM ref_unit_of_measure WHERE code='NMB'),
     20000.0000, '1', 21100.0000, 21100.0000);

-- ---- 3. Valuation note (freight + insurance apportioned to item CIF) -----
-- FOB total 60000; freight 3000 + insurance 300 apportioned by FOB share (2:1).
INSERT INTO valuation_note
    (declaration_id, invoice_currency_id, total_invoice_fob, external_freight,
     internal_freight, insurance, other_costs, total_cif)
VALUES
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     (SELECT id FROM ref_currency WHERE iso_code='USD'),
     60000.0000, 3000.0000, 0.0000, 300.0000, 0.0000, 63300.0000);

INSERT INTO item_value_note
    (declaration_item_id, item_fob, apportioned_freight, apportioned_insurance, apportioned_other, item_cif)
VALUES
    ((SELECT di.id FROM declaration_item di JOIN declaration d ON d.id=di.declaration_id
      WHERE d.trader_reference='REF-2026-0001' AND di.item_number=1),
     40000.0000, 2000.0000, 200.0000, 0.0000, 42200.0000),
    ((SELECT di.id FROM declaration_item di JOIN declaration d ON d.id=di.declaration_id
      WHERE d.trader_reference='REF-2026-0001' AND di.item_number=2),
     20000.0000, 1000.0000, 100.0000, 0.0000, 21100.0000);

-- ---- 4. Tax lines (per item, per tax: base, rate, amount) ----------------
-- Item 1 phones: IMP 5% of 42200 = 2110; VAT 10% of (42200+2110)=44310 -> 4431
INSERT INTO declaration_tax_line
    (declaration_item_id, tax_type_id, tax_base, rate_percent, tax_amount, mode_of_payment)
VALUES
    ((SELECT di.id FROM declaration_item di JOIN declaration d ON d.id=di.declaration_id
      WHERE d.trader_reference='REF-2026-0001' AND di.item_number=1),
     (SELECT id FROM ref_tax_type WHERE code='IMP'), 42200.0000, 5.0000, 2110.0000, 'cash'),
    ((SELECT di.id FROM declaration_item di JOIN declaration d ON d.id=di.declaration_id
      WHERE d.trader_reference='REF-2026-0001' AND di.item_number=1),
     (SELECT id FROM ref_tax_type WHERE code='VAT'), 44310.0000, 10.0000, 4431.0000, 'cash');
-- Item 2 T-shirts: IMP 15% of 21100 = 3165; VAT 10% of (21100+3165)=24265 -> 2426.50
INSERT INTO declaration_tax_line
    (declaration_item_id, tax_type_id, tax_base, rate_percent, tax_amount, mode_of_payment)
VALUES
    ((SELECT di.id FROM declaration_item di JOIN declaration d ON d.id=di.declaration_id
      WHERE d.trader_reference='REF-2026-0001' AND di.item_number=2),
     (SELECT id FROM ref_tax_type WHERE code='IMP'), 21100.0000, 15.0000, 3165.0000, 'cash'),
    ((SELECT di.id FROM declaration_item di JOIN declaration d ON d.id=di.declaration_id
      WHERE d.trader_reference='REF-2026-0001' AND di.item_number=2),
     (SELECT id FROM ref_tax_type WHERE code='VAT'), 24265.0000, 10.0000, 2426.5000, 'cash');

-- ---- 5. Attached & previous documents ------------------------------------
INSERT INTO declaration_attached_document (declaration_id, document_type_id, document_reference, document_date)
VALUES
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     (SELECT id FROM ref_document_type WHERE code='380'), 'INV-SZ-55120', DATE '2026-06-18'),
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     (SELECT id FROM ref_document_type WHERE code='705'), 'POL-BL-88231', DATE '2026-06-20');

-- Previous document: write off each item against the manifest B/L (box 40)
INSERT INTO declaration_previous_document
    (declaration_id, declaration_item_id, bl_id, reference, written_off_packages, written_off_mass)
VALUES
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     (SELECT di.id FROM declaration_item di JOIN declaration d ON d.id=di.declaration_id
      WHERE d.trader_reference='REF-2026-0001' AND di.item_number=1),
     (SELECT id FROM bill_of_lading WHERE bl_reference='POL-BL-88231'), 'POL-BL-88231', 100, 1800.000),
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     (SELECT di.id FROM declaration_item di JOIN declaration d ON d.id=di.declaration_id
      WHERE d.trader_reference='REF-2026-0001' AND di.item_number=2),
     (SELECT id FROM bill_of_lading WHERE bl_reference='POL-BL-88231'), 'POL-BL-88231', 150, 2400.000);

-- ---- 6. Lifecycle: stored -> registered -> assessed -> paid -> released --
INSERT INTO declaration_status_history (declaration_id, status_id, changed_by, note) VALUES
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     (SELECT id FROM ref_declaration_status WHERE code='stored'),
     (SELECT id FROM sys_user WHERE login_name='broker.jdoe'), 'Draft captured'),
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     (SELECT id FROM ref_declaration_status WHERE code='registered'),
     (SELECT id FROM sys_user WHERE login_name='broker.jdoe'), 'Validated & registered (C 427)'),
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     (SELECT id FROM ref_declaration_status WHERE code='assessed'),
     (SELECT id FROM sys_user WHERE login_name='broker.jdoe'), 'Assessed: duties & taxes calculated');

-- Selectivity triggered -> RED -> inspection performed
INSERT INTO selectivity_result (declaration_id, lane_id, criterion_id, officer_id, note) VALUES
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     (SELECT id FROM ref_selectivity_lane WHERE code='RED'),
     (SELECT id FROM risk_criterion WHERE code='HS-HIGHRISK'),
     (SELECT id FROM sys_user WHERE login_name='cust.aofficer'), 'Routed RED: electronics chapter');

INSERT INTO inspection_act (declaration_id, officer_id, inspected_at, result, findings) VALUES
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     (SELECT id FROM sys_user WHERE login_name='cust.aofficer'),
     TIMESTAMPTZ '2026-07-06 10:30:00+11', 'conform', 'Goods conform to declaration; released');

-- Payment of assessed amount (2110+4431+3165+2426.50 = 12132.50) + receipt
INSERT INTO payment (declaration_id, account_id, amount, currency_id, mode_of_payment, paid_by) VALUES
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'), NULL,
     12132.5000, (SELECT id FROM ref_currency WHERE iso_code='USD'), 'cash',
     (SELECT id FROM sys_user WHERE login_name='broker.jdoe'));

INSERT INTO receipt (payment_id, receipt_number, receipt_date, total_amount) VALUES
    ((SELECT p.id FROM payment p JOIN declaration d ON d.id=p.declaration_id
      WHERE d.trader_reference='REF-2026-0001'),
     'RCPT-2026-0427', DATE '2026-07-06', 12132.5000);

-- paid + released status, then flip the declaration header status to released
INSERT INTO declaration_status_history (declaration_id, status_id, changed_by, note) VALUES
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     (SELECT id FROM ref_declaration_status WHERE code='paid'),
     (SELECT id FROM sys_user WHERE login_name='broker.jdoe'), 'Paid — receipt RCPT-2026-0427'),
    ((SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     (SELECT id FROM ref_declaration_status WHERE code='released'),
     (SELECT id FROM sys_user WHERE login_name='cust.aofficer'), 'Release order issued');

UPDATE declaration
   SET status_id = (SELECT id FROM ref_declaration_status WHERE code='released'),
       assessment_number = 'A-2026-0427', assessment_date = DATE '2026-07-06'
 WHERE trader_reference = 'REF-2026-0001';

INSERT INTO audit_log (entity_name, entity_id, action, actor_id, detail) VALUES
    ('declaration',
     (SELECT id FROM declaration WHERE trader_reference='REF-2026-0001'),
     'status_change',
     (SELECT id FROM sys_user WHERE login_name='cust.aofficer'),
     'Declaration C 427 released after RED-lane inspection and payment');

COMMIT;

-- ---- Verification read-out ----------------------------------------------
\echo '--- Declaration summary ---'
SELECT d.registration_serial||' '||d.registration_number AS reg,
       dt.code AS type, st.code AS status, lane.code AS lane,
       d.total_items, d.total_cif_value
FROM declaration d
JOIN ref_declaration_type dt ON dt.id=d.declaration_type_id
JOIN ref_declaration_status st ON st.id=d.status_id
JOIN ref_selectivity_lane lane ON lane.id=d.selectivity_lane_id
WHERE d.trader_reference='REF-2026-0001';

\echo '--- Items with tax totals ---'
SELECT di.item_number, di.hs_code, di.customs_value,
       sum(tl.tax_amount) AS taxes
FROM declaration_item di
JOIN declaration d ON d.id=di.declaration_id
LEFT JOIN declaration_tax_line tl ON tl.declaration_item_id=di.id
WHERE d.trader_reference='REF-2026-0001'
GROUP BY di.item_number, di.hs_code, di.customs_value
ORDER BY di.item_number;

\echo '--- Total assessed vs receipt ---'
SELECT (SELECT sum(tax_amount) FROM declaration_tax_line tl
        JOIN declaration_item di ON di.id=tl.declaration_item_id
        JOIN declaration d ON d.id=di.declaration_id
        WHERE d.trader_reference='REF-2026-0001') AS total_assessed,
       (SELECT total_amount FROM receipt WHERE receipt_number='RCPT-2026-0427') AS receipt_amount;

\echo '--- Lifecycle trail ---'
SELECT s.sort_order, st.code, h.note
FROM declaration_status_history h
JOIN ref_declaration_status st ON st.id=h.status_id
JOIN ref_declaration_status s ON s.id=h.status_id
JOIN declaration d ON d.id=h.declaration_id
WHERE d.trader_reference='REF-2026-0001'
ORDER BY h.changed_at;

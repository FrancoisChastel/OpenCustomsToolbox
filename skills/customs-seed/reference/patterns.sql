-- =====================================================================
-- patterns.sql — copy-paste templates for seeding the customs model.
-- Load AFTER schema/asycuda.sql + schema/seed_reference.sql.
-- Change the *_reference / codes / TINs for each new record so they stay UNIQUE.
-- =====================================================================
SET search_path TO asycuda, public;

-- ---------------------------------------------------------------------
-- A · Reference values (extend the code tables)
-- ---------------------------------------------------------------------
-- Countries — src: ISO 3166 (representative sample)
INSERT INTO ref_country (iso_alpha2, iso_alpha3, numeric_code, name) VALUES
    ('AU','AUS','036','Australia')
ON CONFLICT (iso_alpha2) DO NOTHING;

-- Tax type — src: S003 box 47
INSERT INTO ref_tax_type (code, name, is_ad_valorem) VALUES
    ('ENV','Environmental levy', true)
ON CONFLICT (code) DO NOTHING;

-- HS commodity (parent chapter then subheading) — src: S003 box 33
INSERT INTO ref_hs_tariff (hs_code, parent_id, description, uom_id) VALUES
    ('8471', NULL, 'Automatic data-processing machines', NULL)
ON CONFLICT (hs_code) DO NOTHING;
INSERT INTO ref_hs_tariff (hs_code, parent_id, description, uom_id) VALUES
    ('847130', (SELECT id FROM ref_hs_tariff WHERE hs_code='8471'),
     'Portable ADP machines <10kg', (SELECT id FROM ref_unit_of_measure WHERE code='NMB'))
ON CONFLICT (hs_code) DO NOTHING;

-- Customs office — src: S008
INSERT INTO ref_customs_office (office_code, name, country_id) VALUES
    ('FMYAP','Yap Customs Office', (SELECT id FROM ref_country WHERE iso_alpha2='FM'))
ON CONFLICT (office_code) DO NOTHING;

-- ---------------------------------------------------------------------
-- B · A minimal complete declaration (1 item, GREEN lane, cash paid)
--     Duplicate this block and vary the CAPITALISED placeholders.
-- ---------------------------------------------------------------------
BEGIN;

-- parties (obviously-synthetic names/TINs for sample data)
INSERT INTO trader (tin, name, address, country_id) VALUES
    ('SMPLEXP1','Sample Exporter Co','Overseas', (SELECT id FROM ref_country WHERE iso_alpha2='CN')),
    ('SMPLIMP1','Sample Importer Ltd','Pohnpei', (SELECT id FROM ref_country WHERE iso_alpha2='FM'))
ON CONFLICT (tin) DO NOTHING;

-- header
INSERT INTO declaration
    (office_id, declaration_type_id, cpc_id, registration_serial, registration_number,
     registration_date, trader_reference, exporter_id, consignee_id, declarant_id, financial_id,
     country_export_id, country_origin_id, country_destination_id,
     incoterm_id, transport_mode_border_id, total_items, total_packages,
     currency_id, total_invoice_amount, exchange_rate, total_freight, total_insurance,
     total_cif_value, selectivity_lane_id, status_id)
VALUES
    ((SELECT id FROM ref_customs_office     WHERE office_code='FMPNI'),
     (SELECT id FROM ref_declaration_type   WHERE code='IM4'),
     (SELECT id FROM ref_cpc_regime         WHERE cpc_code='4000'),
     'C', 501, DATE '2026-08-01', 'REF-SEED-0501',                 -- << change per record
     (SELECT id FROM trader WHERE tin='SMPLEXP1'),
     (SELECT id FROM trader WHERE tin='SMPLIMP1'),
     (SELECT id FROM trader WHERE tin='SMPLIMP1'),
     (SELECT id FROM trader WHERE tin='SMPLIMP1'),
     (SELECT id FROM ref_country WHERE iso_alpha2='CN'),
     (SELECT id FROM ref_country WHERE iso_alpha2='CN'),
     (SELECT id FROM ref_country WHERE iso_alpha2='FM'),
     (SELECT id FROM ref_incoterm WHERE code='CIF'),
     (SELECT id FROM ref_transport_mode WHERE code='1'),
     1, 40,
     (SELECT id FROM ref_currency WHERE iso_code='USD'), 10000.0000, 1.000000, 500.0000, 50.0000,
     10550.0000,
     (SELECT id FROM ref_selectivity_lane WHERE code='GREEN'),
     (SELECT id FROM ref_declaration_status WHERE code='stored'));

-- one item (customs_value = item CIF = the tax base)
INSERT INTO declaration_item
    (declaration_id, item_number, hs_id, hs_code, goods_description, country_origin_id,
     cpc_id, national_procedure, number_of_packages, package_type_id,
     gross_mass, net_mass, item_price, valuation_method_code, statistical_value, customs_value)
VALUES
    ((SELECT id FROM declaration WHERE trader_reference='REF-SEED-0501'),
     1, (SELECT id FROM ref_hs_tariff WHERE hs_code='851712'), '851712', 'Sample phones',
     (SELECT id FROM ref_country WHERE iso_alpha2='CN'),
     (SELECT id FROM ref_cpc_regime WHERE cpc_code='4000'), '000',
     40, (SELECT id FROM ref_package_type WHERE code='CT'),
     420.000, 400.000, 10000.0000, '1', 10550.0000, 10550.0000);

-- valuation build-up + per-item apportionment
INSERT INTO valuation_note
    (declaration_id, invoice_currency_id, total_invoice_fob, external_freight,
     internal_freight, insurance, other_costs, total_cif)
VALUES
    ((SELECT id FROM declaration WHERE trader_reference='REF-SEED-0501'),
     (SELECT id FROM ref_currency WHERE iso_code='USD'),
     10000.0000, 500.0000, 0.0000, 50.0000, 0.0000, 10550.0000);

INSERT INTO item_value_note
    (declaration_item_id, item_fob, apportioned_freight, apportioned_insurance, apportioned_other, item_cif)
VALUES
    ((SELECT di.id FROM declaration_item di JOIN declaration d ON d.id=di.declaration_id
      WHERE d.trader_reference='REF-SEED-0501' AND di.item_number=1),
     10000.0000, 500.0000, 50.0000, 0.0000, 10550.0000);

-- taxes: IMP 5% of 10550 = 527.50 ; VAT 10% of (10550+527.50)=11077.50 -> 1107.75
INSERT INTO declaration_tax_line
    (declaration_item_id, tax_type_id, tax_base, rate_percent, tax_amount, mode_of_payment)
VALUES
    ((SELECT di.id FROM declaration_item di JOIN declaration d ON d.id=di.declaration_id
      WHERE d.trader_reference='REF-SEED-0501' AND di.item_number=1),
     (SELECT id FROM ref_tax_type WHERE code='IMP'), 10550.0000, 5.0000, 527.5000, 'cash'),
    ((SELECT di.id FROM declaration_item di JOIN declaration d ON d.id=di.declaration_id
      WHERE d.trader_reference='REF-SEED-0501' AND di.item_number=1),
     (SELECT id FROM ref_tax_type WHERE code='VAT'), 11077.5000, 10.0000, 1107.7500, 'cash');

-- lifecycle: stored -> registered -> assessed -> paid -> released (GREEN: no inspection)
INSERT INTO declaration_status_history (declaration_id, status_id, note)
SELECT (SELECT id FROM declaration WHERE trader_reference='REF-SEED-0501'),
       id, code
FROM ref_declaration_status
WHERE code IN ('stored','registered','assessed','paid','released');

-- payment (527.50 + 1107.75 = 1635.25) + receipt
INSERT INTO payment (declaration_id, amount, currency_id, mode_of_payment)
VALUES ((SELECT id FROM declaration WHERE trader_reference='REF-SEED-0501'),
        1635.2500, (SELECT id FROM ref_currency WHERE iso_code='USD'), 'cash');

INSERT INTO receipt (payment_id, receipt_number, receipt_date, total_amount)
VALUES ((SELECT p.id FROM payment p JOIN declaration d ON d.id=p.declaration_id
         WHERE d.trader_reference='REF-SEED-0501'),
        'RCPT-SEED-0501', DATE '2026-08-01', 1635.2500);

UPDATE declaration
   SET status_id = (SELECT id FROM ref_declaration_status WHERE code='released')
 WHERE trader_reference = 'REF-SEED-0501';

COMMIT;

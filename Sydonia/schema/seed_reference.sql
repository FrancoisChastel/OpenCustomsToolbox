-- =====================================================================
-- seed_reference.sql — reference / code-table seed data
-- Loads AFTER schema/asycuda.sql. Code-list values are grounded in the
-- cited sources where the source enumerates them (S008 mode of transport,
-- B/L nature; S002/S005 selectivity lanes; S002 declaration statuses);
-- representative ISO/UN/WCO/Incoterms values are seeded as illustrative
-- samples of the referenced standard, not an exhaustive catalogue.
-- =====================================================================

BEGIN;
SET search_path TO asycuda, public;

-- Countries (ISO 3166-1) — representative sample. src: S008 (nationality = ISO country)
INSERT INTO ref_country (iso_alpha2, iso_alpha3, numeric_code, name) VALUES
    ('FM','FSM','583','Micronesia (Federated States of)'),
    ('US','USA','840','United States of America'),
    ('CN','CHN','156','China'),
    ('JP','JPN','392','Japan'),
    ('DE','DEU','276','Germany'),
    ('GB','GBR','826','United Kingdom'),
    ('SG','SGP','702','Singapore');

-- Currencies (ISO 4217) — representative sample. src: S008 (freight currency = ISO 4217)
INSERT INTO ref_currency (iso_code, numeric_code, name, minor_units) VALUES
    ('USD','840','US Dollar',2),
    ('CNY','156','Chinese Yuan Renminbi',2),
    ('JPY','392','Yen',0),
    ('EUR','978','Euro',2);

-- Exchange rates (SAD box 23). -- inferred sample rates
INSERT INTO ref_exchange_rate (currency_id, rate, valid_from) VALUES
    ((SELECT id FROM ref_currency WHERE iso_code='CNY'), 0.140000, DATE '2026-01-01'),
    ((SELECT id FROM ref_currency WHERE iso_code='USD'), 1.000000, DATE '2026-01-01'),
    ((SELECT id FROM ref_currency WHERE iso_code='EUR'), 1.080000, DATE '2026-01-01');

-- Customs offices. src: S008 (customs_office_code AN5)
INSERT INTO ref_customs_office (office_code, name, country_id) VALUES
    ('FMPNI','Pohnpei Customs Office', (SELECT id FROM ref_country WHERE iso_alpha2='FM')),
    ('FMKSA','Kosrae Customs Office',  (SELECT id FROM ref_country WHERE iso_alpha2='FM'));

-- Locations / ports (UN/LOCODE) — representative sample. src: S008
INSERT INTO ref_location (unlocode, name, country_id, is_port) VALUES
    ('FMPNI','Pohnpei',   (SELECT id FROM ref_country WHERE iso_alpha2='FM'), true),
    ('CNSHA','Shanghai',  (SELECT id FROM ref_country WHERE iso_alpha2='CN'), true),
    ('USLAX','Los Angeles',(SELECT id FROM ref_country WHERE iso_alpha2='US'), true),
    ('SGSIN','Singapore', (SELECT id FROM ref_country WHERE iso_alpha2='SG'), true);

-- Mode of transport — full code list. src: S008
INSERT INTO ref_transport_mode (code, name) VALUES
    ('1','Sea'),('2','Rail'),('3','Road'),('4','Air'),('5','Postal'),
    ('6','Multimodal'),('7','Fixed transport installation'),('8','Inland waterways'),('9','Unknown');

-- Package types (UN/ECE Rec 21 alpha-2) — representative sample. src: S008
INSERT INTO ref_package_type (code, name) VALUES
    ('CT','Carton'),('BX','Box'),('CS','Case'),('PK','Package'),
    ('PL','Pallet'),('BG','Bag'),('DR','Drum'),('CN','Container');

-- Container size-types (ISO 6346:1995) — representative sample. src: S008
INSERT INTO ref_container_type (code, name) VALUES
    ('22G1','20ft general purpose'),
    ('42G1','40ft general purpose'),
    ('45R1','40ft high-cube reefer');

-- Units of measure. -- inferred (standard measurement units)
INSERT INTO ref_unit_of_measure (code, name) VALUES
    ('KGM','Kilogram'),('NMB','Number (unit)'),('LTR','Litre'),('MTR','Metre'),('TNE','Tonne');

-- Incoterms — representative sample. src: S012 (SAD box 20, S003)
INSERT INTO ref_incoterm (code, name, edition) VALUES
    ('EXW','Ex Works','2020'),
    ('FOB','Free On Board','2020'),
    ('CFR','Cost and Freight','2020'),
    ('CIF','Cost, Insurance and Freight','2020'),
    ('DAP','Delivered At Place','2020');

-- HS tariff (Harmonized System) — chapters + sample subheadings. src: S003 (box 33), S008
INSERT INTO ref_hs_tariff (hs_code, parent_id, description, uom_id) VALUES
    ('8517', NULL, 'Telephone sets and apparatus for transmission of voice/data', NULL),
    ('6109', NULL, 'T-shirts, singlets and other vests, knitted or crocheted', NULL);
INSERT INTO ref_hs_tariff (hs_code, parent_id, description, uom_id) VALUES
    ('851712', (SELECT id FROM ref_hs_tariff WHERE hs_code='8517'),
        'Telephones for cellular networks / other wireless networks',
        (SELECT id FROM ref_unit_of_measure WHERE code='NMB')),
    ('610910', (SELECT id FROM ref_hs_tariff WHERE hs_code='6109'),
        'T-shirts etc., of cotton',
        (SELECT id FROM ref_unit_of_measure WHERE code='NMB'));

-- Customs Procedure Codes / regimes (SAD box 37). src: S003
INSERT INTO ref_cpc_regime (cpc_code, name, regime_group, is_suspense) VALUES
    ('4000','Direct entry for home use (import)','import',false),
    ('1000','Permanent export','export',false),
    ('7000','Entry for warehousing','warehouse',true),
    ('5000','Temporary admission','temporary',true),
    ('8000','Transit','transit',true);

-- Tax types (SAD box 47). src: S003
INSERT INTO ref_tax_type (code, name, is_ad_valorem) VALUES
    ('IMP','Import duty',true),
    ('VAT','Value Added Tax',true),
    ('EXC','Excise tax',true),
    ('CSF','Customs service fee',true);

-- Tax rates. -- inferred sample rates keyed on commodity
INSERT INTO ref_tax_rate (tax_type_id, hs_id, rate_percent, valid_from) VALUES
    ((SELECT id FROM ref_tax_type WHERE code='IMP'),(SELECT id FROM ref_hs_tariff WHERE hs_code='851712'), 5.0000, DATE '2026-01-01'),
    ((SELECT id FROM ref_tax_type WHERE code='VAT'),(SELECT id FROM ref_hs_tariff WHERE hs_code='851712'),10.0000, DATE '2026-01-01'),
    ((SELECT id FROM ref_tax_type WHERE code='IMP'),(SELECT id FROM ref_hs_tariff WHERE hs_code='610910'),15.0000, DATE '2026-01-01'),
    ((SELECT id FROM ref_tax_type WHERE code='VAT'),(SELECT id FROM ref_hs_tariff WHERE hs_code='610910'),10.0000, DATE '2026-01-01');

-- Document types (SAD box 44). src: S003, S008
INSERT INTO ref_document_type (code, name) VALUES
    ('380','Commercial invoice'),
    ('705','Bill of lading'),
    ('271','Packing list'),
    ('911','Import licence'),
    ('861','Certificate of origin');

-- Exemption / Additional National Codes (SAD box 37 national procedure). src: S003
INSERT INTO ref_exemption_code (code, name, description) VALUES
    ('000','No exemption','Standard duty/tax treatment'),
    ('GOV','Government exemption','Goods imported by government, duty/tax relieved');

-- Declaration types (SAD box 1). src: S003
INSERT INTO ref_declaration_type (code, name, direction) VALUES
    ('IM4','Import for home use','import'),
    ('IM7','Import for warehousing','import'),
    ('IM5','Temporary import','import'),
    ('EX1','Permanent export','export'),
    ('EX3','Re-export','export'),
    ('IM8','Transit','transit');

-- Declaration statuses (lifecycle). src: S002
INSERT INTO ref_declaration_status (code, name, sort_order) VALUES
    ('stored','Stored (draft)',1),
    ('registered','Registered',2),
    ('assessed','Assessed',3),
    ('paid','Paid',4),
    ('released','Released',5),
    ('queried','Queried',6),
    ('cancelled','Cancelled',7);

-- Manifest statuses. -- inferred lifecycle
INSERT INTO ref_manifest_status (code, name, sort_order) VALUES
    ('stored','Stored',1),
    ('registered','Registered',2),
    ('amended','Amended',3),
    ('closed','Closed',4);

-- Bill-of-lading nature (S008 Bol_nature). src: S008
INSERT INTO ref_bl_nature (code, name) VALUES
    ('22','Exports'),
    ('23','Imports'),
    ('24','In-Transit'),
    ('26','Freight remaining on board (FROB)'),
    ('28','Transhipment');

-- Selectivity lanes. src: S002, S005
INSERT INTO ref_selectivity_lane (code, name, requires_exam, description) VALUES
    ('GREEN','Green lane',false,'Automatic release; customs reserves the right to examine'),
    ('YELLOW','Yellow lane',true,'Documentary check by assigned officer'),
    ('RED','Red lane',true,'Physical examination of goods'),
    ('BLUE','Blue lane',false,'Released, selected for post-clearance audit');

-- Risk criteria. -- inferred sample
INSERT INTO risk_criterion (code, name, target_lane_id) VALUES
    ('HS-HIGHRISK','High-risk commodity chapter', (SELECT id FROM ref_selectivity_lane WHERE code='RED')),
    ('NEW-TRADER','First-time importer', (SELECT id FROM ref_selectivity_lane WHERE code='YELLOW'));

COMMIT;

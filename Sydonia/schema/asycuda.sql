-- =====================================================================
-- asycuda.sql — SYDONIA / ASYCUDA World reference data model (PostgreSQL)
-- Reconstruction from PUBLIC documentation only. See SOURCES.md for IDs.
-- Provenance: every table-creation statement carries `-- src: <ID>` (ID in SOURCES.md)
-- or `-- inferred` (introduced by modelling judgement; see COVERAGE.md).
-- Conventions (GOAL §6): snake_case; ref_/sys_ prefixes; surrogate PKs
-- `bigint GENERATED ALWAYS AS IDENTITY`; business codes UNIQUE NOT NULL;
-- money numeric(18,4); mass/qty numeric(18,3). Runs top-to-bottom.
-- Target: PostgreSQL 14+ (avoids 15-only features).
-- =====================================================================

BEGIN;

-- Idempotent load: drop the schema if re-running against an existing DB.
DROP SCHEMA IF EXISTS asycuda CASCADE;
CREATE SCHEMA asycuda;
SET search_path TO asycuda, public;

-- =====================================================================
-- MODULE 1 — REFERENCE / CONFIGURATION (GOAL §4.1)
-- =====================================================================

-- src: S013, S008   (official xxCTYTAB Countries; ISO 3166)
CREATE TABLE ref_country (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    iso_alpha2    varchar(2)  UNIQUE NOT NULL,   -- ISO 3166-1 alpha-2
    iso_alpha3    varchar(3)  UNIQUE,            -- ISO 3166-1 alpha-3
    numeric_code  varchar(3),                    -- ISO 3166-1 numeric
    name          varchar(100) NOT NULL,
    is_active     boolean NOT NULL DEFAULT true,
    CONSTRAINT ck_country_alpha2 CHECK (iso_alpha2 = upper(iso_alpha2))
);
COMMENT ON TABLE ref_country IS 'ISO 3166 countries; used for origin, export, destination, nationality (S008).';

-- src: S013, S008   (official xxCURTAB Currencies; ISO 4217)
CREATE TABLE ref_currency (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    iso_code      varchar(3) UNIQUE NOT NULL,    -- ISO 4217 alpha-3
    numeric_code  varchar(3),
    name          varchar(80) NOT NULL,
    minor_units   smallint NOT NULL DEFAULT 2,
    is_active     boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE ref_currency IS 'ISO 4217 currencies for invoice / freight / insurance values (S008, S003 box 22).';

-- src: S013   (official xxRATTAB Exchange rates; SAD box 23)
CREATE TABLE ref_exchange_rate (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    currency_id   bigint NOT NULL REFERENCES ref_currency(id),
    rate          numeric(18,6) NOT NULL,        -- units of national currency per 1 foreign unit
    valid_from    date NOT NULL,
    valid_to      date,
    CONSTRAINT uq_exchange_rate UNIQUE (currency_id, valid_from),
    CONSTRAINT ck_exchange_rate_pos CHECK (rate > 0),
    CONSTRAINT ck_exchange_rate_period CHECK (valid_to IS NULL OR valid_to >= valid_from)
);
COMMENT ON TABLE ref_exchange_rate IS 'Exchange rate applied to convert invoice currency (SAD box 23); table shape inferred.';

-- src: S013, S008   (official xxCUOTAB Customs offices)
CREATE TABLE ref_customs_office (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    office_code   varchar(5) UNIQUE NOT NULL,    -- AN5 (S008)
    name          varchar(120) NOT NULL,
    country_id    bigint REFERENCES ref_country(id),
    is_active     boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE ref_customs_office IS 'Customs offices (S008 customs_office_code AN5; S003 office of entry box 29).';

-- src: S013, S008   (official xxLOCTAB Places of loading / UN/LOCODE)
CREATE TABLE ref_location (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    unlocode      varchar(5) UNIQUE NOT NULL,    -- UN/LOCODE (2-alpha country + 3-alnum)
    name          varchar(120) NOT NULL,
    country_id    bigint REFERENCES ref_country(id),
    is_port       boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE ref_location IS 'UN/LOCODE places/ports of loading, unloading, departure, destination (S008).';

-- src: S013, S008   (official xxMOTTAB Modes of transport)
CREATE TABLE ref_transport_mode (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(3) UNIQUE NOT NULL,    -- 1=Sea..9=Unknown (S008)
    name          varchar(40) NOT NULL
);
COMMENT ON TABLE ref_transport_mode IS 'Mode of transport 1=Sea 2=Rail 3=Road 4=Air 5=Postal 6=Multimodal 7=Fixed 8=Inland waterways 9=Unknown (S008).';

-- src: S013, S008   (official xxPKGTAB Types of packages; UN/ECE Rec 21)
CREATE TABLE ref_package_type (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(2) UNIQUE NOT NULL,    -- UN/ECE Rec 21 alpha-2
    name          varchar(80) NOT NULL
);
COMMENT ON TABLE ref_package_type IS 'Kind-of-packages codes, UN/ECE Rec 21 alpha-2 (S008 package_type_code; S003 box 31).';

-- src: S013, S008   (official xxCTNTAB Types of containers; ISO 6346)
CREATE TABLE ref_container_type (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(4) UNIQUE NOT NULL,    -- ISO 6346:1995 size-type
    name          varchar(80) NOT NULL
);
COMMENT ON TABLE ref_container_type IS 'Container size-type per ISO 6346:1995 (S008 type_of_container).';

-- src: S013   (official xxUOMTAB Statistical units; SAD box 41)
CREATE TABLE ref_unit_of_measure (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(6) UNIQUE NOT NULL,
    name          varchar(60) NOT NULL
);
COMMENT ON TABLE ref_unit_of_measure IS 'Units for supplementary quantity / statistical units (SAD box 41, S003); values inferred.';

-- src: S013, S003, S012   (official xxTODTAB Terms of delivery; Incoterms)
CREATE TABLE ref_incoterm (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(3) UNIQUE NOT NULL,    -- e.g. CIF, FOB, EXW
    name          varchar(60) NOT NULL,
    edition       varchar(9)                     -- e.g. '2020'
);
COMMENT ON TABLE ref_incoterm IS 'Incoterms delivery-terms codes (SAD box 20, S003; S012).';

-- src: S013, S003   (official xxHS1-6TAB / xxTARTAB commodity codes)
CREATE TABLE ref_hs_tariff (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hs_code       varchar(12) UNIQUE NOT NULL,   -- national tariff code (>= HS6)
    parent_id     bigint REFERENCES ref_hs_tariff(id),  -- hierarchy
    description   varchar(400) NOT NULL,
    uom_id        bigint REFERENCES ref_unit_of_measure(id),  -- statistical unit
    is_active     boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE ref_hs_tariff IS 'Harmonized System commodity codes with self-referential hierarchy (SAD box 33, S003; S008 HS 6-digit).';

-- src: S013, S003   (official xxCP1TAB/xxCP3TAB/xxCP4TAB procedures; SAD box 37)
CREATE TABLE ref_cpc_regime (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cpc_code      varchar(7) UNIQUE NOT NULL,    -- extended procedure (e.g. 4000) [+ national]
    name          varchar(120) NOT NULL,
    regime_group  varchar(30),                   -- import/export/transit/warehouse/temporary
    is_suspense   boolean NOT NULL DEFAULT false,
    is_active     boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE ref_cpc_regime IS 'Customs Procedure Codes / regimes (SAD box 37, S003): requested(2)+previous(2) extended code.';

-- src: S013, S003   (official xxTAXTAB Tax codes; SAD box 47)
CREATE TABLE ref_tax_type (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(6) UNIQUE NOT NULL,    -- e.g. IMP (import duty), VAT, EXC
    name          varchar(80) NOT NULL,
    is_ad_valorem boolean NOT NULL DEFAULT true   -- ad valorem vs specific
);
COMMENT ON TABLE ref_tax_type IS 'Duty/tax/fee types calculated per item (SAD box 47, S003).';

-- src: S013   (official xxRULTAB Taxation Rules / xxTAXTAR)
CREATE TABLE ref_tax_rate (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tax_type_id   bigint NOT NULL REFERENCES ref_tax_type(id),
    hs_id         bigint REFERENCES ref_hs_tariff(id),   -- rate may key on commodity
    cpc_id        bigint REFERENCES ref_cpc_regime(id),  -- and/or regime
    origin_id     bigint REFERENCES ref_country(id),     -- and/or preferential origin
    rate_percent  numeric(9,4),                  -- ad valorem %
    specific_amount numeric(18,4),               -- specific amount per unit
    valid_from    date NOT NULL DEFAULT DATE '2000-01-01',
    valid_to      date,
    CONSTRAINT ck_tax_rate_kind CHECK (rate_percent IS NOT NULL OR specific_amount IS NOT NULL),
    CONSTRAINT ck_tax_rate_period CHECK (valid_to IS NULL OR valid_to >= valid_from)
);
COMMENT ON TABLE ref_tax_rate IS 'Applicable rate per tax type / commodity / regime / origin (SAD box 47 implies rates); table shape inferred.';

-- src: S013, S003, S008   (official xxATDTAB Attached documents; SAD box 44)
CREATE TABLE ref_document_type (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(6) UNIQUE NOT NULL,
    name          varchar(120) NOT NULL          -- invoice, licence, permit, certificate...
);
COMMENT ON TABLE ref_document_type IS 'Attached/supporting document types (SAD box 44, S003; S008 attached_document_code).';

-- src: S013, S003   (official xxCP3TAB Additional codes / SAD_Relief; box 37)
CREATE TABLE ref_exemption_code (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(6) UNIQUE NOT NULL,    -- Additional National Code (ANC)
    name          varchar(120) NOT NULL,
    description   varchar(300)
);
COMMENT ON TABLE ref_exemption_code IS 'Additional National Codes granting special duty/tax treatment (SAD box 37 national procedure, S003).';

-- src: S013, S003   (official xxMODTAB Models of declarations; SAD box 1)
CREATE TABLE ref_declaration_type (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(4) UNIQUE NOT NULL,    -- e.g. IM4, EX1, SD4
    name          varchar(80) NOT NULL,
    direction     varchar(10) NOT NULL,          -- import/export/transit
    CONSTRAINT ck_decl_type_dir CHECK (direction IN ('import','export','transit'))
);
COMMENT ON TABLE ref_declaration_type IS 'Declaration type codes (SAD box 1, S003): first letters model, digit = extended procedure.';

-- src: S014, S002   (official SAD serials/STA lifecycle; finder statuses)
CREATE TABLE ref_declaration_status (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(15) UNIQUE NOT NULL,   -- stored, registered, assessed, paid, released...
    name          varchar(60) NOT NULL,
    sort_order    smallint NOT NULL DEFAULT 0
);
COMMENT ON TABLE ref_declaration_status IS 'Declaration lifecycle: stored->registered->assessed->paid->released (+queried/cancelled) (S002).';

-- src: S015   (official GEN_TAB STA manifest status)
CREATE TABLE ref_manifest_status (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(15) UNIQUE NOT NULL,
    name          varchar(60) NOT NULL,
    sort_order    smallint NOT NULL DEFAULT 0
);
COMMENT ON TABLE ref_manifest_status IS 'Manifest lifecycle (stored/registered/amended/closed); inferred from S006/S011 workflow.';

-- src: S013, S008   (official xxNATTAB B/L nature)
CREATE TABLE ref_bl_nature (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(2) UNIQUE NOT NULL,
    name          varchar(60) NOT NULL
);
COMMENT ON TABLE ref_bl_nature IS 'Transport-document nature codes (S008 Bol_nature).';

-- src: S014, S002, S005   (official SAD_General_Segment PTY colour flags; lanes)
CREATE TABLE ref_selectivity_lane (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(6) UNIQUE NOT NULL,    -- GREEN/YELLOW/RED/BLUE
    name          varchar(40) NOT NULL,
    requires_exam boolean NOT NULL DEFAULT false,
    description   varchar(200)
);
COMMENT ON TABLE ref_selectivity_lane IS 'Selectivity lanes green/yellow/red/blue (S002, S005).';

-- =====================================================================
-- MODULE 2 — TRADERS & SYSTEM USERS (GOAL §4.1)
-- =====================================================================

-- src: S013, S003, S008   (official xxCARTAB/xxDECTAB/xxCMPTAB/xxPRPTAB; TIN)
CREATE TABLE trader (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tin           varchar(20) UNIQUE NOT NULL,   -- TIN / business ID (S003 box 8/14)
    name          varchar(140) NOT NULL,
    address       varchar(200),
    country_id    bigint REFERENCES ref_country(id),
    is_active     boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE trader IS 'Economic operators: importer/exporter/consignee/declarant/broker/carrier, keyed by TIN (S003, S008).';

-- inferred   (a trader can hold several roles; the role catalogue/junction is a modelling choice)
CREATE TABLE trader_role (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    trader_id     bigint NOT NULL REFERENCES trader(id),
    role          varchar(20) NOT NULL,          -- importer/exporter/broker/carrier/agent/warehouse
    CONSTRAINT uq_trader_role UNIQUE (trader_id, role),
    CONSTRAINT ck_trader_role CHECK (role IN
        ('importer','exporter','broker','carrier','agent','consignee','warehouse_keeper'))
);
COMMENT ON TABLE trader_role IS 'Roles a trader may act in; inferred normalisation of the single trader/economic-operator concept.';

-- src: S002   (only registered users may use ASYCUDA World; login name issued by Customs)
CREATE TABLE sys_user (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    login_name    varchar(40) UNIQUE NOT NULL,
    full_name     varchar(120) NOT NULL,
    trader_id     bigint REFERENCES trader(id),  -- external users tie to a trader
    office_id     bigint REFERENCES ref_customs_office(id), -- customs staff tie to an office
    is_active     boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE sys_user IS 'System users (customs staff, brokers, traders); registration required (S002).';

-- inferred   (roles/permissions exist implicitly; explicit RBAC tables are a modelling choice)
CREATE TABLE sys_role (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(30) UNIQUE NOT NULL,
    name          varchar(80) NOT NULL
);
COMMENT ON TABLE sys_role IS 'RBAC roles; inferred (ASYCUDA World has role-based menus but no public schema).';

-- inferred
CREATE TABLE sys_permission (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(40) UNIQUE NOT NULL,
    name          varchar(120) NOT NULL
);
COMMENT ON TABLE sys_permission IS 'RBAC permissions; inferred.';

-- inferred
CREATE TABLE sys_user_role (
    user_id       bigint NOT NULL REFERENCES sys_user(id),
    role_id       bigint NOT NULL REFERENCES sys_role(id),
    PRIMARY KEY (user_id, role_id)
);

-- inferred
CREATE TABLE sys_role_permission (
    role_id       bigint NOT NULL REFERENCES sys_role(id),
    permission_id bigint NOT NULL REFERENCES sys_permission(id),
    PRIMARY KEY (role_id, permission_id)
);

-- =====================================================================
-- MODULE 3 — MANIFEST / CARGO (GOAL §4.2)
-- =====================================================================

-- src: S015, S008, S006   (official GEN_TAB Manifest General Segment)
CREATE TABLE manifest (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    office_id             bigint NOT NULL REFERENCES ref_customs_office(id),   -- customs_office_code
    manifest_year         smallint NOT NULL,             -- manifest reference year (S003 "2024 12")
    registration_number   integer,                       -- manifest reference number (assigned on registration)
    voyage_number         varchar(17) NOT NULL,          -- voyage/flight number (S008)
    transport_mode_id     bigint NOT NULL REFERENCES ref_transport_mode(id),
    identity_of_transport varchar(40),                   -- vessel/aircraft name (S008)
    nationality_id        bigint REFERENCES ref_country(id),  -- transporter nationality (ISO)
    registration_ref      varchar(35),                   -- IMO/IATA registration reference
    master_name           varchar(70),                   -- master/captain name
    carrier_id            bigint REFERENCES trader(id),  -- carrier (S008 Carrier)
    shipping_agent_id     bigint REFERENCES trader(id),  -- shipping agent (S008 Shipping_Agent)
    place_departure_id    bigint REFERENCES ref_location(id),  -- place/port of departure (UN/LOCODE)
    place_destination_id  bigint REFERENCES ref_location(id),  -- place/port of destination
    date_of_departure     date,
    date_of_arrival       date,
    date_of_last_discharge date,
    total_bols            integer,                       -- totals segment (S008)
    total_packages        numeric(18,3),
    total_containers      integer,
    total_gross_mass      numeric(18,3),                 -- KG
    tonnage_net           numeric(18,3),
    tonnage_gross         numeric(18,3),
    status_id             bigint REFERENCES ref_manifest_status(id),
    created_at            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_manifest_ref UNIQUE (office_id, manifest_year, registration_number)
);
COMMENT ON TABLE manifest IS 'Cargo manifest general segment: carrier, voyage, ports, dates, totals, office (S008, S006).';

-- src: S015, S008, S006   (official BOL_TAB Bill of lading; master/house)
CREATE TABLE bill_of_lading (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    manifest_id           bigint NOT NULL REFERENCES manifest(id),
    line_number           integer NOT NULL,              -- transport-document sequence line no.
    bl_reference          varchar(35) NOT NULL,          -- B/L or AWB number
    bl_nature_id          bigint NOT NULL REFERENCES ref_bl_nature(id),  -- exports/imports/transit/FROB/transhipment
    bl_type_code          varchar(3),                    -- transport document type
    is_master             boolean NOT NULL DEFAULT false,-- master vs house B/L
    master_bl_id          bigint REFERENCES bill_of_lading(id),  -- house B/L points to its master (degroupage)
    exporter_id           bigint REFERENCES trader(id),  -- exporter/supplier (S008 Exporter)
    consignee_id          bigint REFERENCES trader(id),  -- consignee (S008 Consignee)
    notify_id             bigint REFERENCES trader(id),  -- notify party (S008 Notify)
    place_loading_id      bigint REFERENCES ref_location(id),
    place_unloading_id    bigint REFERENCES ref_location(id),
    number_of_packages    numeric(18,3),                 -- goods segment total packages
    package_type_id       bigint REFERENCES ref_package_type(id),
    gross_mass            numeric(18,3),                 -- KG for this transport document
    goods_description     varchar(2000),
    volume_m3             numeric(18,3),
    freight_indicator     varchar(2),                    -- PP=Prepaid / CC=Collect (S008 PC_indicator)
    freight_value         numeric(18,4),
    freight_currency_id   bigint REFERENCES ref_currency(id),
    customs_value         numeric(18,4),
    insurance_value       numeric(18,4),
    CONSTRAINT uq_bl_line UNIQUE (manifest_id, line_number),
    CONSTRAINT ck_freight_ind CHECK (freight_indicator IS NULL OR freight_indicator IN ('PP','CC'))
);
COMMENT ON TABLE bill_of_lading IS 'Transport document (B/L/AWB). House B/L = a consignment; master_bl_id models consolidation/degroupage (S008, S006, S010).';

-- src: S015, S008   (official CTN_TAB / BOL_CTN_TAB Containers)
CREATE TABLE container (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bl_id                 bigint NOT NULL REFERENCES bill_of_lading(id),
    ctn_reference         varchar(17) NOT NULL,          -- container ID (owner4+serial6+check) ISO 6346
    container_type_id     bigint REFERENCES ref_container_type(id),
    number_of_packages    integer,
    empty_full            varchar(10),                   -- empty/full indicator
    seal1                 varchar(10),                   -- 1st seal number
    seal2                 varchar(10),
    empty_weight          numeric(18,3),
    goods_weight          numeric(18,3),                 -- gross mass of goods in container
    volume_m3             numeric(18,3),
    dangerous_goods_code  varchar(10),                   -- UNDG
    goods_description     varchar(500)
);
COMMENT ON TABLE container IS 'Containers per B/L; reference/size-type follow ISO 6346 (S008 ctn_segment).';

-- src: S015, S008   (official BOL goods lines; XML Goods/Commodity segment)
CREATE TABLE manifest_cargo_item (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bl_id                 bigint NOT NULL REFERENCES bill_of_lading(id),
    line_number           integer NOT NULL,
    hs_code               varchar(6),                    -- 6-digit HS (S008 Goods_hs_code)
    goods_description      varchar(500) NOT NULL,
    number_of_packages    numeric(18,3),
    package_type_id       bigint REFERENCES ref_package_type(id),
    gross_mass            numeric(18,3),
    container_id          bigint REFERENCES container(id),
    CONSTRAINT uq_cargo_item UNIQUE (bl_id, line_number)
);
COMMENT ON TABLE manifest_cargo_item IS 'Goods/commodity lines within a transport document (S008 Goods_segment/Commodity_Segment).';

-- inferred   (S006/S011 imply a manifest document lifecycle; explicit history table is a modelling choice)
CREATE TABLE manifest_status_history (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    manifest_id   bigint NOT NULL REFERENCES manifest(id),
    status_id     bigint NOT NULL REFERENCES ref_manifest_status(id),
    changed_at    timestamptz NOT NULL DEFAULT now(),
    changed_by    bigint REFERENCES sys_user(id),
    note          varchar(200)
);
COMMENT ON TABLE manifest_status_history IS 'Manifest status transitions; inferred lifecycle table.';

-- =====================================================================
-- MODULE 4 — DECLARATION (THE SAD) (GOAL §4.3)
-- =====================================================================

-- src: S014, S003, S001   (official SAD_General_Segment)
CREATE TABLE declaration (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    office_id             bigint NOT NULL REFERENCES ref_customs_office(id),   -- box 29 / office of lodgement
    declaration_type_id   bigint NOT NULL REFERENCES ref_declaration_type(id),-- box 1
    cpc_id                bigint REFERENCES ref_cpc_regime(id),               -- box 37 header regime
    registration_serial   varchar(2),                    -- serial letter (e.g. 'C')
    registration_number   integer,                        -- assigned on registration (e.g. 427)
    registration_date     date,
    trader_reference      varchar(35),                    -- box 7 unique trader reference
    exporter_id           bigint REFERENCES trader(id),   -- box 2
    consignee_id          bigint REFERENCES trader(id),   -- box 8
    declarant_id          bigint REFERENCES trader(id),   -- box 14 (broker/agent or trader)
    financial_id          bigint REFERENCES trader(id),   -- box 9 party paying duties
    country_export_id     bigint REFERENCES ref_country(id),   -- box 15
    country_origin_id     bigint REFERENCES ref_country(id),   -- box 16 (header; 'Many' if mixed)
    country_destination_id bigint REFERENCES ref_country(id),  -- box 17
    country_last_consign_id bigint REFERENCES ref_country(id), -- box 10
    trading_country_id    bigint REFERENCES ref_country(id),   -- box 11
    incoterm_id           bigint REFERENCES ref_incoterm(id),  -- box 20 delivery terms
    delivery_place        varchar(120),                   -- box 20 place
    transport_mode_border_id bigint REFERENCES ref_transport_mode(id), -- box 25
    transport_mode_inland_id bigint REFERENCES ref_transport_mode(id), -- box 26
    border_transport_identity varchar(60),                -- box 21 identity/nationality crossing border
    place_of_discharge_id bigint REFERENCES ref_location(id),   -- box 27
    total_items           smallint,                       -- box 5
    total_packages        numeric(18,3),                  -- box 6
    currency_id           bigint REFERENCES ref_currency(id),  -- box 22
    total_invoice_amount  numeric(18,4),                  -- box 22
    exchange_rate         numeric(18,6),                  -- box 23
    total_freight         numeric(18,4),                  -- from valuation note
    total_insurance       numeric(18,4),
    total_cif_value       numeric(18,4),                  -- customs value total
    selectivity_lane_id   bigint REFERENCES ref_selectivity_lane(id),  -- assigned lane
    status_id             bigint NOT NULL REFERENCES ref_declaration_status(id),
    assessment_number     varchar(20),                    -- box B accounting details
    assessment_date       date,
    manifest_id           bigint REFERENCES manifest(id), -- consignment link (may be NULL pre-arrival)
    created_by            bigint REFERENCES sys_user(id),
    created_at            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_declaration_reg UNIQUE (office_id, registration_serial, registration_number, registration_date)
);
COMMENT ON TABLE declaration IS 'SAD general segment — one per consignment: parties, regime, transport, invoice totals, status, selectivity (S003 boxes 1-49/B, S001).';

-- src: S014, S003   (official SAD_Item)
CREATE TABLE declaration_item (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_id        bigint NOT NULL REFERENCES declaration(id) ON DELETE CASCADE,
    item_number           smallint NOT NULL,              -- box 32 line number
    hs_id                 bigint REFERENCES ref_hs_tariff(id),   -- box 33 commodity code
    hs_code               varchar(12) NOT NULL,           -- captured code (denormalised for audit)
    goods_description     varchar(500),                   -- box 31 description
    country_origin_id     bigint REFERENCES ref_country(id),     -- box 34
    cpc_id                bigint REFERENCES ref_cpc_regime(id),  -- box 37 extended procedure
    national_procedure    varchar(3),                     -- box 37 Additional National Code (ANC)
    exemption_id          bigint REFERENCES ref_exemption_code(id), -- box 37 special treatment
    preference_code       varchar(3),                     -- box 36
    number_of_packages    numeric(18,3),                  -- box 31
    package_type_id       bigint REFERENCES ref_package_type(id),
    marks_and_numbers     varchar(200),                   -- box 31 marks1/marks2
    container_reference   varchar(17),                    -- box 31 container no.
    gross_mass            numeric(18,3),                  -- box 35
    net_mass              numeric(18,3),                  -- box 38
    supplementary_qty     numeric(18,3),                  -- box 41
    supplementary_uom_id  bigint REFERENCES ref_unit_of_measure(id),
    item_price            numeric(18,4),                  -- box 42
    valuation_method_code varchar(3),                     -- box 43
    adjustment_indicator  numeric(9,4),                   -- box 45
    statistical_value     numeric(18,4),                  -- box 46 (tax base)
    customs_value         numeric(18,4),                  -- item CIF / customs value
    quota                 varchar(20),                    -- box 39
    warehouse_id          bigint,                         -- box 49 (FK added after warehouse table)
    warehouse_days        integer,                        -- box 49 time delay
    CONSTRAINT uq_declaration_item UNIQUE (declaration_id, item_number)
);
COMMENT ON TABLE declaration_item IS 'SAD item segment (boxes 31-49): commodity, origin, mass, procedure, valuation, statistical value = tax base (S003).';

-- src: S003, S017   (valuation note build-up; official SAD processing manual)
CREATE TABLE valuation_note (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_id        bigint NOT NULL UNIQUE REFERENCES declaration(id) ON DELETE CASCADE,
    invoice_currency_id   bigint REFERENCES ref_currency(id),
    total_invoice_fob     numeric(18,4),                  -- goods value before add-ons
    external_freight      numeric(18,4),                  -- S003: external freight
    internal_freight      numeric(18,4),                  -- S003: internal freight
    insurance             numeric(18,4),                  -- S003: insurance
    other_costs           numeric(18,4),
    total_cif             numeric(18,4)                   -- resulting customs value
);
COMMENT ON TABLE valuation_note IS 'Declaration-level value build-up: freight + insurance + other -> CIF customs value (S003 valuation note).';

-- src: S014, S003   (official SAD_Item VIT_CIF/VIT_STV per-item value)
CREATE TABLE item_value_note (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_item_id   bigint NOT NULL UNIQUE REFERENCES declaration_item(id) ON DELETE CASCADE,
    item_fob              numeric(18,4),
    apportioned_freight   numeric(18,4),                  -- freight apportioned to this item
    apportioned_insurance numeric(18,4),
    apportioned_other     numeric(18,4),
    item_cif              numeric(18,4)                   -- customs value = tax base for the item
);
COMMENT ON TABLE item_value_note IS 'Freight/insurance apportioned per item to produce item CIF, the tax base (S003 valuation note; box 46).';

-- src: S014, S003   (official SAD_Tax: COD/BSE/RAT/AMT/MOP; box 47)
CREATE TABLE declaration_tax_line (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_item_id   bigint NOT NULL REFERENCES declaration_item(id) ON DELETE CASCADE,
    tax_type_id           bigint NOT NULL REFERENCES ref_tax_type(id),
    tax_base              numeric(18,4) NOT NULL,         -- box 47 tax base
    rate_percent          numeric(9,4),                   -- box 47 rate (ad valorem)
    specific_amount       numeric(18,4),                  -- specific component
    tax_amount            numeric(18,4) NOT NULL,         -- box 47 calculated amount
    mode_of_payment       varchar(6),                     -- box 47 mode of payment
    is_manual             boolean NOT NULL DEFAULT false,  -- official SAD_Tax.TYP manual/automatic flag (S014)
    CONSTRAINT uq_tax_line UNIQUE (declaration_item_id, tax_type_id)
);
COMMENT ON TABLE declaration_tax_line IS 'Per-item per-tax calculation: base, rate, amount, mode of payment (SAD box 47, S003).';

-- src: S014, S003, S008   (official SAD_Attached_Documents; box 44)
CREATE TABLE declaration_attached_document (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_id        bigint NOT NULL REFERENCES declaration(id) ON DELETE CASCADE,
    declaration_item_id   bigint REFERENCES declaration_item(id) ON DELETE CASCADE, -- NULL = header-level
    document_type_id      bigint NOT NULL REFERENCES ref_document_type(id),
    document_reference    varchar(60),                    -- licence/permit/invoice no.
    document_date         date
);
COMMENT ON TABLE declaration_attached_document IS 'Attached/supporting documents at header or item level (SAD box 44, S003; S008).';

-- src: S014, S003, S008   (official SAD_Int Previous Documents; box 40)
CREATE TABLE declaration_previous_document (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_id        bigint NOT NULL REFERENCES declaration(id) ON DELETE CASCADE,
    declaration_item_id   bigint REFERENCES declaration_item(id) ON DELETE CASCADE,
    bl_id                 bigint REFERENCES bill_of_lading(id),  -- write-off against a manifest B/L
    prev_declaration_id   bigint REFERENCES declaration(id),     -- or a previous declaration (suspense)
    reference             varchar(60),                    -- box 40 free reference when not linked
    written_off_packages  numeric(18,3),
    written_off_mass      numeric(18,3)
);
COMMENT ON TABLE declaration_previous_document IS 'SAD box 40: links items to the manifest B/L or a previous declaration (write-off) (S003, S008).';

-- src: S014, S002   (official registration/assessment/receipt serials; lifecycle)
CREATE TABLE declaration_status_history (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_id        bigint NOT NULL REFERENCES declaration(id) ON DELETE CASCADE,
    status_id             bigint NOT NULL REFERENCES ref_declaration_status(id),
    changed_at            timestamptz NOT NULL DEFAULT now(),
    changed_by            bigint REFERENCES sys_user(id),
    note                  varchar(200)
);
COMMENT ON TABLE declaration_status_history IS 'Declaration status transitions over its lifecycle (S002).';

-- =====================================================================
-- MODULE 5 — SELECTIVITY / RISK (GOAL §4.6)
-- =====================================================================

-- src: S014   (official SEL_PARAM_TAB / SEL_*_PARAM_TAB selectivity criteria)
CREATE TABLE risk_criterion (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(20) UNIQUE NOT NULL,
    name          varchar(120) NOT NULL,
    target_lane_id bigint REFERENCES ref_selectivity_lane(id),
    is_active     boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE risk_criterion IS 'Risk/selectivity criteria driving lane assignment; inferred (S002 references criteria, no public schema).';

-- src: S014, S002, S005   (official SAD_General_Segment PTY colour flags)
CREATE TABLE selectivity_result (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_id bigint NOT NULL REFERENCES declaration(id) ON DELETE CASCADE,
    lane_id       bigint NOT NULL REFERENCES ref_selectivity_lane(id),
    criterion_id  bigint REFERENCES risk_criterion(id),
    triggered_at  timestamptz NOT NULL DEFAULT now(),
    officer_id    bigint REFERENCES sys_user(id),
    note          varchar(300)
);
COMMENT ON TABLE selectivity_result IS 'Lane assigned to a declaration when selectivity is triggered (S002, S005).';

-- src: S014, S002, S005   (official INSP_ACT_TAB Inspection Act)
CREATE TABLE inspection_act (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_id bigint NOT NULL REFERENCES declaration(id) ON DELETE CASCADE,
    officer_id    bigint REFERENCES sys_user(id),
    inspected_at  timestamptz,
    result        varchar(20),                    -- e.g. conform / discrepancy
    findings      varchar(1000)
);
COMMENT ON TABLE inspection_act IS 'Inspection/examination act for red/yellow declarations, feeding release (S002, S005).';

-- =====================================================================
-- MODULE 6 — ACCOUNTING (GOAL §4.4)
-- =====================================================================

-- src: S016, S003   (official xxATITAB/xxATOTAB accounting transactions; box 48)
CREATE TABLE account (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_number varchar(20) UNIQUE NOT NULL,
    trader_id     bigint REFERENCES trader(id),
    account_type  varchar(20) NOT NULL,           -- credit / prepayment / guarantee
    currency_id   bigint REFERENCES ref_currency(id),
    balance       numeric(18,4) NOT NULL DEFAULT 0,
    is_active     boolean NOT NULL DEFAULT true,
    CONSTRAINT ck_account_type CHECK (account_type IN ('credit','prepayment','guarantee'))
);
COMMENT ON TABLE account IS 'Trader deferred-payment/credit/prepayment accounts (SAD box 48, S003).';

-- src: S016, S003, S005   (official receipts / TAX_TAB; box B)
CREATE TABLE payment (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_id bigint NOT NULL REFERENCES declaration(id),
    account_id    bigint REFERENCES account(id),   -- NULL = cash
    amount        numeric(18,4) NOT NULL,
    currency_id   bigint REFERENCES ref_currency(id),
    mode_of_payment varchar(20) NOT NULL,          -- cash / account / cheque
    paid_at       timestamptz NOT NULL DEFAULT now(),
    paid_by       bigint REFERENCES sys_user(id)
);
COMMENT ON TABLE payment IS 'Payment of assessed amount, cash or against an account (S003 box B, S005).';

-- src: S016, S003   (official SER_LETTERS_TAB/SER_NBERING_TAB receipt serials; box B)
CREATE TABLE receipt (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_id    bigint NOT NULL REFERENCES payment(id),
    receipt_number varchar(20) UNIQUE NOT NULL,
    receipt_date  date NOT NULL,
    total_amount  numeric(18,4) NOT NULL
);
COMMENT ON TABLE receipt IS 'Receipt issued on payment of a declaration (SAD box B, S003).';

-- src: S016   (official account transactions in/out)
CREATE TABLE account_movement (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id    bigint NOT NULL REFERENCES account(id),
    payment_id    bigint REFERENCES payment(id),
    movement_type varchar(10) NOT NULL,            -- debit / credit
    amount        numeric(18,4) NOT NULL,
    balance_after numeric(18,4),
    moved_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_movement_type CHECK (movement_type IN ('debit','credit'))
);
COMMENT ON TABLE account_movement IS 'Ledger movements against an account; inferred.';

-- src: S019, S003   (official suspense guarantees; SAD box 52)
CREATE TABLE guarantee (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reference     varchar(30) UNIQUE NOT NULL,
    trader_id     bigint REFERENCES trader(id),
    guarantee_type varchar(20),                    -- cash/bond/bank
    amount        numeric(18,4) NOT NULL,
    currency_id   bigint REFERENCES ref_currency(id),
    valid_from    date,
    valid_to      date,
    is_active     boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE guarantee IS 'Security/guarantee for suspense regimes (SAD box 52 references it, S003); table shape inferred.';

-- =====================================================================
-- MODULE 7 — TRANSIT & SUSPENSE (GOAL §4.5)
-- =====================================================================

-- src: S014, S019, S003   (official MAN_TRANSIT_TAB / suspense; boxes 50-53)
CREATE TABLE transit_declaration (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_id        bigint NOT NULL REFERENCES declaration(id) ON DELETE CASCADE,
    principal_id          bigint REFERENCES trader(id),   -- box 50 principal
    office_departure_id   bigint REFERENCES ref_customs_office(id),
    office_transit_id     bigint REFERENCES ref_customs_office(id),  -- box 51
    office_destination_id bigint REFERENCES ref_customs_office(id),  -- box 53
    guarantee_id          bigint REFERENCES guarantee(id),           -- box 52
    itinerary             varchar(300),
    seals_affixed         varchar(200),
    time_limit_date       date
);
COMMENT ON TABLE transit_declaration IS 'Transit declaration extension: principal, offices, guarantee, itinerary (SAD boxes 50-53, S003).';

-- src: S013, S019, S003   (official xxWHSTAB Warehouses; suspense manual; box 49)
CREATE TABLE ref_warehouse (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          varchar(10) UNIQUE NOT NULL,
    name          varchar(120) NOT NULL,
    office_id     bigint REFERENCES ref_customs_office(id),
    keeper_id     bigint REFERENCES trader(id),
    is_active     boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE ref_warehouse IS 'Customs/bonded warehouses (SAD box 49 warehouse identification, S003).';

-- Deferred FK: declaration_item.warehouse_id -> ref_warehouse (created here to avoid forward reference)
ALTER TABLE declaration_item
    ADD CONSTRAINT fk_item_warehouse FOREIGN KEY (warehouse_id) REFERENCES ref_warehouse(id);

-- src: S014, S019   (official SUS_WH_IN warehouse entry/exit management)
CREATE TABLE warehouse_entry (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    warehouse_id  bigint NOT NULL REFERENCES ref_warehouse(id),
    declaration_id bigint REFERENCES declaration(id),
    entry_date    date NOT NULL,
    packages      numeric(18,3),
    gross_mass    numeric(18,3)
);
COMMENT ON TABLE warehouse_entry IS 'Goods placed under warehousing regime; inferred from S003 box 49 suspense.';

-- src: S014, S019   (official SUS_WH_IN warehouse entry/exit management)
CREATE TABLE warehouse_exit (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    warehouse_entry_id bigint NOT NULL REFERENCES warehouse_entry(id),
    declaration_id bigint REFERENCES declaration(id),  -- ex-warehouse declaration
    exit_date     date NOT NULL,
    packages      numeric(18,3),
    gross_mass    numeric(18,3)
);
COMMENT ON TABLE warehouse_exit IS 'Removal of goods from warehouse (write-off); inferred.';

-- src: S019   (official suspense temporary admission regime)
CREATE TABLE temporary_admission (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_id bigint NOT NULL REFERENCES declaration(id) ON DELETE CASCADE,
    guarantee_id  bigint REFERENCES guarantee(id),
    time_limit_date date,
    re_export_declaration_id bigint REFERENCES declaration(id)
);
COMMENT ON TABLE temporary_admission IS 'Temporary admission suspense regime with time limit and re-export link; inferred (S003 box 49).';

-- =====================================================================
-- MODULE 8 — AUDIT / WORKFLOW (cross-cutting) (GOAL §4.7)
-- =====================================================================

-- src: S013   (official LogTable Actions/procedures audit)
CREATE TABLE audit_log (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_name   varchar(60) NOT NULL,           -- table/document type affected
    entity_id     bigint,                         -- surrogate id of the affected row
    action        varchar(20) NOT NULL,           -- insert/update/status_change/print...
    actor_id      bigint REFERENCES sys_user(id),
    occurred_at   timestamptz NOT NULL DEFAULT now(),
    detail        varchar(1000)
);
COMMENT ON TABLE audit_log IS 'Cross-cutting who/what/when audit trail; inferred.';

-- Helpful indexes on the busiest foreign keys.
CREATE INDEX ix_decl_item_declaration ON declaration_item(declaration_id);
CREATE INDEX ix_tax_line_item        ON declaration_tax_line(declaration_item_id);
CREATE INDEX ix_bl_manifest          ON bill_of_lading(manifest_id);
CREATE INDEX ix_cargo_item_bl        ON manifest_cargo_item(bl_id);
CREATE INDEX ix_decl_status_hist     ON declaration_status_history(declaration_id);

COMMIT;

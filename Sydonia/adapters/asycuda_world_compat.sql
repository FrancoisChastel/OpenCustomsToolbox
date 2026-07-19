-- =====================================================================
-- asycuda_world_compat.sql — ASYCUDA World COMPATIBILITY (adapter) views
-- ---------------------------------------------------------------------
-- WHAT THIS IS
--   A read-only ADAPTER LAYER that makes a REAL ASYCUDA World database
--   answer the queries this toolbox writes against its NORMALISED reference
--   model (Sydonia/schema/asycuda.sql). Each view below is named EXACTLY
--   like one of our tables and SELECTs-and-aliases from the real, WIDE,
--   denormalised AW tables (SAD_General_Segment, SAD_Item, SAD_Tax,
--   GEN_TAB, BOL_TAB, the UN*/xx*TAB reference tables). Point our queries,
--   the customs-query skill and the customs-query-tester at this schema and
--   they run UNCHANGED against the live system.
--
-- THIS IS A TEMPLATE — IT WILL NOT RUN AS-IS.
--   ASYCUDA World's PHYSICAL schema (exact table + column names) is NOT
--   public — it is the #1 "must-request" gap (see docs/platform/integration.md).
--   So every place where the public docs (Sydonia/FIT.md, docs/platform/
--   xml-messages.md) do NOT pin an exact physical column name is marked
--   `-- TODO(instance):`. A DBA fills those once, per deployment, using the
--   real schema/ERD you obtain from your national customs administration or
--   UNCTAD. Where FIT.md / xml-messages.md DO give a real name (e.g. SAD_Tax
--   COD/BSE/RAT/AMT/MOP, the GEN_*/BOL_* segment prefixes), it is used below.
--
-- READ-ONLY STANCE
--   Views only. No writes, no DDL against AW's own objects. The customs-query-
--   tester's privacy guarantees (read-only session, metadata-only) therefore
--   hold on real data. Grant a SELECT-only role and, ideally, run against a
--   READ-REPLICA. See Sydonia/adapters/README.md.
--
-- TARGET: PostgreSQL. If the AW instance runs on Oracle / MS SQL Server,
--   either (a) create equivalent views there in AW's own dialect, or
--   (b) stand these views up in a Postgres front-end over FOREIGN TABLES via
--   oracle_fdw / tds_fdw (import the real tables as foreign tables, then build
--   these views on top). The view CONTRACTS (the column set each view must
--   expose) are identical whichever route you take.
--
-- CONTRACT
--   The load-bearing promise of each view is its OUTPUT COLUMN SET: it must
--   match, name-for-name, the columns our schema exposes (verified against
--   Sydonia/schema/asycuda.sql). The FROM/SELECT body is deployment-specific
--   and is what the -- TODO(instance) markers cover.
-- =====================================================================

-- Our queries and tooling default to search_path = asycuda,public and address
-- tables unqualified (e.g. `FROM declaration`). Creating the views in a schema
-- literally named `asycuda` means EVERY existing query, the customs-query skill
-- and test_query.sh work VERBATIM — no rewrite. (If you cannot use the name
-- `asycuda` on this server, use `compat` and set CUSTOMS_SCHEMA=compat instead;
-- the view bodies are unchanged.)
CREATE SCHEMA IF NOT EXISTS asycuda;
SET search_path TO asycuda, public;

-- =====================================================================
-- SHAPE GOTCHAS THIS ADAPTER HANDLES (see FIT.md "Aspect" table)
-- ---------------------------------------------------------------------
--  1. KEYS: AW uses engine keys INSTANCE_ID / InstanceId; we expose them
--     AS id so our surrogate-PK joins keep working.
--  2. CODE+NAME INLINE vs FK: AW stores code AND name together on the row
--     (e.g. GEN_CAR_COD + GEN_CAR_NAM). Our model stores an FK to a ref_*
--     table. We CANNOT synthesise our surrogate ref_*.id without a lookup,
--     so the ref_* views below are CODE-KEYED (id := the business code) and
--     the operational views expose that SAME code as the *_id column. A join
--     `declaration.office_id = ref_customs_office.id` then resolves on the
--     office CODE on both sides — honest and consistent, no fabricated keys.
--  3. GENERAL SEGMENT REPEATED: AW repeats the general segment into every
--     SAD_Item row. The `declaration` header view must therefore DE-DUPLICATE
--     (SELECT DISTINCT on the general-segment columns, or read from a keyed
--     header source if the instance has one).
--  4. HS SPLIT: the commodity code is split across TAR_HSC_NB1..NB5; the
--     `declaration_item` view CONCATENATES them into our single hs_code.
--  5. REFERENCE VALIDITY: UN*/xx*TAB reference rows carry VALID_FROM/VALID_TO.
--     Each ref_* view filters to currently-valid rows
--     (WHERE now()::date BETWEEN valid_from AND coalesce(valid_to,'9999-12-31')).
-- =====================================================================


-- =====================================================================
-- MODULE 1 — REFERENCE / CODE TABLES  (AW: UN* / xx*TAB, S013)
-- Each ref_* view is CODE-KEYED: id := the business code, so operational
-- views can expose inline AW codes as our *_id columns and joins resolve.
-- =====================================================================

-- our ref_country  <-  AW xxCTYTAB (Countries)   [FIT.md S013: xxCTYTAB->ref_country]
CREATE OR REPLACE VIEW ref_country AS
SELECT
    c.CTY_COD            AS id,            -- code-keyed surrogate; TODO(instance): confirm PK/code column
    c.CTY_COD            AS iso_alpha2,    -- ISO 3166-1 alpha-2 code
    NULL::varchar(3)     AS iso_alpha3,    -- TODO(instance): alpha-3 col if the table carries one
    NULL::varchar(3)     AS numeric_code,  -- TODO(instance): numeric code if present
    c.CTY_NAM            AS name,          -- inline country name
    true                 AS is_active
FROM xxCTYTAB c                            -- TODO(instance): confirm real reference-table name
WHERE now()::date BETWEEN c.VALID_FROM AND coalesce(c.VALID_TO, DATE '9999-12-31');

-- our ref_currency  <-  AW xxCURTAB (Currencies)  [FIT.md S013: xxCURTAB->ref_currency]
CREATE OR REPLACE VIEW ref_currency AS
SELECT
    c.CUR_COD            AS id,            -- code-keyed surrogate (ISO 4217 alpha-3)
    c.CUR_COD            AS iso_code,
    NULL::varchar(3)     AS numeric_code,  -- TODO(instance): numeric code if present
    c.CUR_NAM            AS name,
    2::smallint          AS minor_units,   -- TODO(instance): from table if carried, else default 2
    true                 AS is_active
FROM xxCURTAB c                            -- TODO(instance): confirm real reference-table name
WHERE now()::date BETWEEN c.VALID_FROM AND coalesce(c.VALID_TO, DATE '9999-12-31');

-- our ref_customs_office  <-  AW xxCUOTAB (Customs offices)  [FIT.md S013: xxCUOTAB->ref_customs_office]
CREATE OR REPLACE VIEW ref_customs_office AS
SELECT
    o.CUO_COD            AS id,            -- code-keyed surrogate (AN5 office code)
    o.CUO_COD            AS office_code,
    o.CUO_NAM            AS name,
    o.CUO_CTY_COD        AS country_id,    -- inline country code == our code-keyed ref_country.id; TODO(instance): confirm col
    true                 AS is_active
FROM xxCUOTAB o                            -- TODO(instance): confirm real reference-table name
WHERE now()::date BETWEEN o.VALID_FROM AND coalesce(o.VALID_TO, DATE '9999-12-31');

-- our ref_tax_type  <-  AW xxTAXTAB (Tax codes, SAD box 47)  [FIT.md S013: xxTAXTAB->ref_tax_type]
CREATE OR REPLACE VIEW ref_tax_type AS
SELECT
    t.TAX_COD            AS id,            -- code-keyed surrogate; matches SAD_Tax "COD"
    t.TAX_COD            AS code,          -- e.g. DOG/DDI duty, TVA/TGC VAT, DA excise, RS statistical
    t.TAX_NAM            AS name,
    true                 AS is_ad_valorem  -- TODO(instance): derive from rate-type col if AW carries it
FROM xxTAXTAB t                            -- TODO(instance): confirm real reference-table name
WHERE now()::date BETWEEN t.VALID_FROM AND coalesce(t.VALID_TO, DATE '9999-12-31');

-- our ref_declaration_status  <-  AW lifecycle status catalogue (STA domain)  [FIT.md S014/S002]
-- AW encodes declaration status as a coded STA value on SAD_General_Segment rather than
-- a rich catalogue table; expose the distinct STA codes so status joins resolve.
CREATE OR REPLACE VIEW ref_declaration_status AS
SELECT DISTINCT
    g.STA                AS id,            -- code-keyed surrogate; the STA lifecycle code
    g.STA                AS code,          -- stored/registered/assessed/paid/released...
    g.STA                AS name,          -- TODO(instance): join a status label table if one exists
    0::smallint          AS sort_order     -- TODO(instance): real ordering if a catalogue exists
FROM SAD_General_Segment g;                -- TODO(instance): confirm real general-segment table name + STA column

-- our ref_selectivity_lane  <-  AW selectivity colour domain (PTY_BLU/RED/YEL/GRE)  [FIT.md S014/S005]
-- AW carries the lane as colour flags on the general segment, not a lane catalogue.
-- Materialise the four canonical lanes so lane joins resolve; adjust if the instance
-- publishes a real lane/colour reference table.
CREATE OR REPLACE VIEW ref_selectivity_lane AS
-- Columns in our contract order: id, code, name, requires_exam, description.
SELECT
    lane.code            AS id,            -- code-keyed surrogate (colour code)
    lane.code            AS code,
    lane.name            AS name,
    lane.requires_exam   AS requires_exam,
    NULL::varchar(200)   AS description
FROM (
    VALUES
        ('GREEN',  'Green — release without control', false),
        ('YELLOW', 'Yellow — documentary check',      true),
        ('RED',    'Red — physical examination',      true),
        ('BLUE',   'Blue — post-clearance audit',     false)
) AS lane(code, name, requires_exam);
-- NOTE: the VALUES form above is a portable stand-in. If the AW instance exposes a real
-- lane/colour reference table, replace with:
--   SELECT l.LANE_COD AS id, l.LANE_COD AS code, l.LANE_NAM AS name,
--          (l.LANE_COD IN ('RED','YELLOW')) AS requires_exam, NULL::varchar(200) AS description
--   FROM <real_lane_table> l;   -- TODO(instance)

-- ---------------------------------------------------------------------
-- Further ref_* views follow the SAME code-keyed pattern. Add per query need:
--   ref_exchange_rate    <- xxRATTAB          -- TODO(instance): RAT_* cols; keep VALID_FROM/TO filter
--   ref_location         <- xxLOCTAB          -- UN/LOCODE places/ports
--   ref_transport_mode   <- xxMOTTAB          -- 1=Sea..9=Unknown
--   ref_package_type     <- xxPKGTAB          -- UN/ECE Rec 21
--   ref_container_type   <- xxCTNTAB          -- ISO 6346
--   ref_unit_of_measure  <- xxUOMTAB
--   ref_incoterm         <- xxTODTAB          -- Incoterms
--   ref_hs_tariff        <- xxHS1-6TAB/xxTARTAB
--   ref_cpc_regime       <- xxCP1/3/4TAB      -- customs procedures
--   ref_tax_rate         <- xxRULTAB/xxTAXTAR
--   ref_document_type    <- xxATDTAB
--   ref_exemption_code   <- xxCP3TAB          -- Additional National Codes
--   ref_declaration_type <- xxMODTAB          -- IM4/EX1...
--   ref_bl_nature        <- xxNATTAB          -- 22/23/24/28
--   ref_manifest_status  <- GEN_TAB.STA distinct
--   ref_warehouse        <- xxWHSTAB
-- All source names above are from FIT.md's S013 crib; the exact *_COD/*_NAM
-- physical column names are per-instance -> TODO(instance).
-- ---------------------------------------------------------------------


-- =====================================================================
-- MODULE 2 — TRADERS  (AW: xxCARTAB/xxDECTAB/xxCMPTAB/xxPRPTAB, S013)
-- FIT.md: these four operator tables collapse into our single `trader`.
-- A UNION over them, keyed by TIN, reconstructs our economic-operator view.
-- =====================================================================
CREATE OR REPLACE VIEW trader AS
SELECT DISTINCT
    o.OP_TIN             AS id,            -- code-keyed surrogate := TIN (our trader is TIN-unique)
    o.OP_TIN             AS tin,
    o.OP_NAM             AS name,
    o.OP_ADR             AS address,       -- TODO(instance): confirm address column
    o.OP_CTY_COD         AS country_id,    -- inline country code -> code-keyed ref_country.id
    true                 AS is_active
FROM (
    -- TODO(instance): UNION the real operator tables with a consistent alias set.
    -- The public crib (FIT.md) names them; the physical *_TIN/*_NAM columns are per-instance.
    SELECT c.CAR_TIN AS OP_TIN, c.CAR_NAM AS OP_NAM, c.CAR_ADR AS OP_ADR, c.CAR_CTY_COD AS OP_CTY_COD FROM xxCARTAB c   -- carriers
    -- UNION ALL SELECT DEC_TIN, DEC_NAM, DEC_ADR, DEC_CTY_COD FROM xxDECTAB   -- declarants  TODO(instance)
    -- UNION ALL SELECT CMP_TIN, CMP_NAM, CMP_ADR, CMP_CTY_COD FROM xxCMPTAB   -- companies   TODO(instance)
    -- UNION ALL SELECT PRP_TIN, PRP_NAM, PRP_ADR, PRP_CTY_COD FROM xxPRPTAB   -- principals  TODO(instance)
) o;


-- =====================================================================
-- MODULE 3 — MANIFEST / CARGO  (AW: GEN_TAB, BOL_TAB, CTN_TAB, S015)
-- =====================================================================

-- our manifest  <-  AW GEN_TAB (Manifest General Segment)  [FIT.md S015: GEN_TAB->manifest]
-- GEN_* is the documented prefix for manifest-general fields (e.g. GEN_CAR_COD carrier code +
-- GEN_CAR_NAM carrier name). We expose GEN_TAB's engine key AS id and the inline codes as *_id.
CREATE OR REPLACE VIEW manifest AS
SELECT
    g.INSTANCE_ID        AS id,                       -- engine key -> our surrogate id
    g.GEN_CUO_COD        AS office_id,                -- inline office code -> code-keyed ref_customs_office.id
    g.GEN_REG_YEAR       AS manifest_year,            -- TODO(instance): confirm reference-year column
    g.GEN_REG_NBR        AS registration_number,      -- TODO(instance): confirm registration-number column
    g.GEN_VOY_NBR        AS voyage_number,            -- voyage/flight number
    g.GEN_MOT_COD        AS transport_mode_id,        -- inline mode code -> code-keyed ref_transport_mode.id
    g.GEN_TRA_IDE        AS identity_of_transport,    -- vessel/aircraft name; TODO(instance): confirm col
    g.GEN_TRA_NAT_COD    AS nationality_id,           -- transporter nationality code -> ref_country.id
    g.GEN_REG_REF        AS registration_ref,         -- TODO(instance): IMO/IATA ref column
    g.GEN_MAS_NAM        AS master_name,              -- TODO(instance): master/captain name column
    g.GEN_CAR_COD        AS carrier_id,               -- inline carrier code -> code-keyed trader.id
    g.GEN_SHA_COD        AS shipping_agent_id,        -- inline shipping-agent code -> trader.id
    g.GEN_DEP_LOC_COD    AS place_departure_id,       -- port of departure (UN/LOCODE) -> ref_location.id
    g.GEN_DES_LOC_COD    AS place_destination_id,     -- port of destination -> ref_location.id
    g.GEN_DEP_DAT        AS date_of_departure,
    g.GEN_ARR_DAT        AS date_of_arrival,
    g.GEN_LDI_DAT        AS date_of_last_discharge,   -- TODO(instance): confirm last-discharge date col
    g.GEN_TOT_BOL        AS total_bols,               -- totals segment
    g.GEN_TOT_PKG        AS total_packages,
    g.GEN_TOT_CTN        AS total_containers,
    g.GEN_TOT_GRW        AS total_gross_mass,         -- KG
    g.GEN_TON_NET        AS tonnage_net,
    g.GEN_TON_GRO        AS tonnage_gross,
    g.STA                AS status_id,                -- manifest STA lifecycle code -> ref_manifest_status.id
    g.GEN_CRE_DAT        AS created_at                -- TODO(instance): confirm creation timestamp col
FROM GEN_TAB g;                                       -- TODO(instance): confirm real manifest general-segment table name

-- our bill_of_lading  <-  AW BOL_TAB (Bill of lading)  [FIT.md S015: BOL_TAB->bill_of_lading]
CREATE OR REPLACE VIEW bill_of_lading AS
SELECT
    b.INSTANCE_ID        AS id,                       -- engine key -> our surrogate id
    b.BOL_GEN_ID         AS manifest_id,              -- FK to parent GEN_TAB row (our manifest.id)
    b.BOL_LIN_NBR        AS line_number,              -- transport-document sequence line no.
    b.BOL_REF            AS bl_reference,             -- B/L or AWB number
    b.BOL_NAT_COD        AS bl_nature_id,             -- 22 exp/23 imp/24 transit/28 transhipment -> ref_bl_nature.id
    b.BOL_TYP_COD        AS bl_type_code,             -- TODO(instance): transport-document type col
    (b.BOL_MASTER = '1') AS is_master,                -- TODO(instance): confirm master/house flag encoding
    b.BOL_MAS_BOL_ID     AS master_bl_id,             -- house B/L -> its master (degroupage)
    b.BOL_EXP_COD        AS exporter_id,              -- inline exporter code -> trader.id
    b.BOL_CNE_COD        AS consignee_id,             -- inline consignee code -> trader.id
    b.BOL_NOT_COD        AS notify_id,                -- inline notify-party code -> trader.id
    b.BOL_LOA_LOC_COD    AS place_loading_id,         -- -> ref_location.id
    b.BOL_UNL_LOC_COD    AS place_unloading_id,       -- -> ref_location.id
    b.BOL_TOT_PKG        AS number_of_packages,
    b.BOL_PKG_COD        AS package_type_id,          -- -> ref_package_type.id
    b.BOL_GRW            AS gross_mass,               -- KG
    b.BOL_GDS_DSC        AS goods_description,        -- TODO(instance): confirm description col
    b.BOL_VOL            AS volume_m3,
    b.BOL_PC_IND         AS freight_indicator,        -- PP prepaid / CC collect
    b.BOL_FRT_VAL        AS freight_value,
    b.BOL_FRT_CUR_COD    AS freight_currency_id,      -- -> ref_currency.id
    b.BOL_CUS_VAL        AS customs_value,
    b.BOL_INS_VAL        AS insurance_value
FROM BOL_TAB b;                                       -- TODO(instance): confirm real bill-of-lading table name

-- our container  <-  AW CTN_TAB / BOL_CTN_TAB (Containers)  [FIT.md S015: CTN_TAB->container]
CREATE OR REPLACE VIEW container AS
SELECT
    ctn.INSTANCE_ID      AS id,
    ctn.CTN_BOL_ID       AS bl_id,                    -- FK to parent BOL_TAB row
    ctn.CTN_REF          AS ctn_reference,            -- ISO 6346 container id
    ctn.CTN_TYP_COD      AS container_type_id,        -- -> ref_container_type.id
    ctn.CTN_PKG_NBR      AS number_of_packages,
    ctn.CTN_EMP_FUL      AS empty_full,               -- empty/full indicator
    ctn.CTN_SEAL1        AS seal1,
    ctn.CTN_SEAL2        AS seal2,
    ctn.CTN_EMP_WGT      AS empty_weight,
    ctn.CTN_GDS_WGT      AS goods_weight,
    ctn.CTN_VOL          AS volume_m3,
    ctn.CTN_DNG_COD      AS dangerous_goods_code,     -- UNDG
    ctn.CTN_GDS_DSC      AS goods_description
FROM CTN_TAB ctn;                                     -- TODO(instance): confirm real container table name (CTN_TAB or BOL_CTN_TAB)


-- =====================================================================
-- MODULE 4 — DECLARATION (THE SAD)  (AW: SAD_General_Segment, SAD_Item, SAD_Tax, S014)
-- =====================================================================

-- our declaration  <-  AW SAD_General_Segment  [FIT.md S014: SAD_General_Segment->declaration]
-- GOTCHA: AW REPEATS the general segment into every SAD_Item row. This header view
-- must therefore de-duplicate to one row per declaration. Prefer a keyed header source
-- if the instance has one; otherwise SELECT DISTINCT on the general-segment columns keyed
-- by the declaration engine id.
CREATE OR REPLACE VIEW declaration AS
SELECT DISTINCT ON (g.INSTANCE_ID)
    g.INSTANCE_ID        AS id,                       -- engine key -> our surrogate id
    g.SGS_CUO_COD        AS office_id,                -- box 29 office code -> ref_customs_office.id
    g.SGS_MOD_COD        AS declaration_type_id,      -- box 1 model code -> ref_declaration_type.id
    g.SGS_CPC_COD        AS cpc_id,                   -- box 37 header regime -> ref_cpc_regime.id
    g.SGS_REG_SER        AS registration_serial,      -- registration serial letter
    g.SGS_REG_NBR        AS registration_number,      -- assigned on registration
    g.SGS_REG_DAT        AS registration_date,
    g.SGS_TRA_REF        AS trader_reference,         -- box 7 (LRN/UCR)
    g.SGS_EXP_COD        AS exporter_id,              -- box 2 exporter code -> trader.id
    g.SGS_CNE_COD        AS consignee_id,             -- box 8 consignee code -> trader.id
    g.SGS_DEC_COD        AS declarant_id,             -- box 14 declarant code -> trader.id
    g.SGS_FIN_COD        AS financial_id,             -- box 9 financial party -> trader.id
    g.SGS_EXP_CTY_COD    AS country_export_id,        -- box 15 -> ref_country.id
    g.SGS_ORG_CTY_COD    AS country_origin_id,        -- box 16 header origin -> ref_country.id
    g.SGS_DES_CTY_COD    AS country_destination_id,   -- box 17 -> ref_country.id
    g.SGS_LCS_CTY_COD    AS country_last_consign_id,  -- box 10 -> ref_country.id
    g.SGS_TRD_CTY_COD    AS trading_country_id,       -- box 11 -> ref_country.id
    g.SGS_TOD_COD        AS incoterm_id,              -- box 20 delivery-terms code -> ref_incoterm.id
    g.SGS_TOD_PLC        AS delivery_place,           -- box 20 place
    g.SGS_BOR_MOT_COD    AS transport_mode_border_id, -- box 25 -> ref_transport_mode.id
    g.SGS_INL_MOT_COD    AS transport_mode_inland_id, -- box 26 -> ref_transport_mode.id
    g.SGS_BOR_TRA_IDE    AS border_transport_identity,-- box 21 identity/nationality at border
    g.SGS_DIS_LOC_COD    AS place_of_discharge_id,    -- box 27 -> ref_location.id
    g.SGS_TOT_ITM        AS total_items,              -- box 5
    g.SGS_TOT_PKG        AS total_packages,           -- box 6
    g.SGS_CUR_COD        AS currency_id,              -- box 22 -> ref_currency.id
    g.SGS_INV_AMT        AS total_invoice_amount,     -- box 22
    g.SGS_CUR_RAT        AS exchange_rate,            -- box 23
    g.SGS_TOT_FRT        AS total_freight,            -- TODO(instance): valuation-total cols
    g.SGS_TOT_INS        AS total_insurance,          -- TODO(instance)
    g.SGS_TOT_CIF        AS total_cif_value,          -- customs-value total; TODO(instance)
    -- Selectivity lane from the PTY_BLU/RED/YEL/GRE colour flags -> our lane code.
    -- (FIT.md/S014 confirm the colour flags; exact flag columns are per-instance.)
    CASE
        WHEN g.PTY_RED = '1' THEN 'RED'
        WHEN g.PTY_YEL = '1' THEN 'YELLOW'
        WHEN g.PTY_BLU = '1' THEN 'BLUE'
        WHEN g.PTY_GRE = '1' THEN 'GREEN'
        ELSE NULL
    END                  AS selectivity_lane_id,      -- -> code-keyed ref_selectivity_lane.id
    g.STA                AS status_id,                -- lifecycle STA code -> ref_declaration_status.id
    g.SGS_ASM_NBR        AS assessment_number,        -- box B
    g.SGS_ASM_DAT        AS assessment_date,          -- box B
    g.SGS_GEN_ID         AS manifest_id,              -- consignment link -> our manifest.id; TODO(instance)
    NULL::bigint         AS created_by,               -- no public equivalent; NULL is honest
    g.SGS_CRE_DAT        AS created_at                -- TODO(instance): confirm creation timestamp col
FROM SAD_General_Segment g                            -- TODO(instance): confirm real general-segment table name
ORDER BY g.INSTANCE_ID;

-- our declaration_item  <-  AW SAD_Item  [FIT.md S014: SAD_Item->declaration_item]
-- GOTCHA: HS code is split across TAR_HSC_NB1..NB5 (national precision) -> concat into hs_code.
CREATE OR REPLACE VIEW declaration_item AS
SELECT
    i.INSTANCE_ID        AS id,                       -- engine key -> our surrogate id
    i.ITM_SGS_ID         AS declaration_id,           -- FK to parent SAD_General_Segment -> declaration.id
    i.ITM_NBR            AS item_number,              -- box 32 line number
    NULL::bigint         AS hs_id,                    -- our ref_hs_tariff surrogate needs a lookup; NULL, use hs_code
    -- HS split TAR_HSC_NB1..NB5 -> single national tariff code (FIT.md/xml-messages box 33)
    concat(i.TAR_HSC_NB1, i.TAR_HSC_NB2, i.TAR_HSC_NB3, i.TAR_HSC_NB4, i.TAR_HSC_NB5) AS hs_code,
    i.ITM_GDS_DSC        AS goods_description,        -- box 31
    i.ITM_ORG_CTY_COD    AS country_origin_id,        -- box 34 -> ref_country.id
    i.ITM_CPC_COD        AS cpc_id,                   -- box 37 extended procedure -> ref_cpc_regime.id
    i.ITM_NAT_PRO        AS national_procedure,       -- box 37 Additional National Code
    i.ITM_RLF_COD        AS exemption_id,             -- box 37 relief/exemption -> ref_exemption_code.id
    i.ITM_PRF_COD        AS preference_code,          -- box 36
    i.ITM_PKG_NBR        AS number_of_packages,       -- box 31
    i.ITM_PKG_COD        AS package_type_id,          -- -> ref_package_type.id
    i.ITM_MRK            AS marks_and_numbers,        -- box 31 marks1/marks2
    i.ITM_CTN_REF        AS container_reference,      -- box 31 container no.
    i.ITM_GRW            AS gross_mass,               -- box 35
    i.ITM_NEW            AS net_mass,                 -- box 38; TODO(instance): confirm net-mass col
    i.ITM_SUP_QTY        AS supplementary_qty,        -- box 41
    i.ITM_SUP_UOM_COD    AS supplementary_uom_id,     -- -> ref_unit_of_measure.id
    i.ITM_INV_AMT        AS item_price,               -- box 42
    i.ITM_VAL_MET        AS valuation_method_code,    -- box 43 (WTO 1-6)
    i.ITM_ADJ            AS adjustment_indicator,     -- box 45
    i.VIT_STV            AS statistical_value,        -- box 46 (FIT.md: VIT_STV->statistical_value)
    i.VIT_CIF            AS customs_value,            -- item CIF (FIT.md: VIT_CIF->customs_value)
    i.ITM_QUO            AS quota,                    -- box 39
    i.ITM_WHS_COD        AS warehouse_id,             -- box 49 -> ref_warehouse.id
    i.ITM_WHS_DLY        AS warehouse_days            -- box 49 time delay
FROM SAD_Item i;                                      -- TODO(instance): confirm real SAD item table name

-- our declaration_tax_line  <-  AW SAD_Tax  [FIT.md S014: SAD_Tax COD/BSE/RAT/AMT/MOP -> our cols]
-- These AW field roots (COD/BSE/RAT/AMT/MOP/TYP) ARE documented (FIT.md, xml-messages box 47),
-- so they are used directly here rather than left as TODO.
CREATE OR REPLACE VIEW declaration_tax_line AS
SELECT
    x.INSTANCE_ID        AS id,                       -- engine key -> our surrogate id
    x.TAX_ITM_ID         AS declaration_item_id,      -- FK to parent SAD_Item -> declaration_item.id; TODO(instance): confirm link col
    x.COD                AS tax_type_id,              -- SAD_Tax COD -> code-keyed ref_tax_type.id
    x.BSE                AS tax_base,                 -- SAD_Tax BSE -> tax base
    x.RAT                AS rate_percent,             -- SAD_Tax RAT -> ad valorem rate
    NULL::numeric(18,4)  AS specific_amount,          -- no distinct AW specific col in the public crib
    x.AMT                AS tax_amount,               -- SAD_Tax AMT -> calculated amount
    x.MOP                AS mode_of_payment,          -- SAD_Tax MOP -> mode of payment (1 payable / 0 guaranteed)
    (x.TYP = '1')        AS is_manual                 -- SAD_Tax TYP -> manual/automatic flag; TODO(instance): confirm manual encoding
FROM SAD_Tax x;                                       -- TODO(instance): confirm real SAD tax table name


-- =====================================================================
-- OPTIONAL HARDENING — grant read-only access to a dedicated role, so even a
-- bug in a client cannot write. Point CUSTOMS_DB at a DSN using this role.
-- =====================================================================
-- CREATE ROLE query_tester LOGIN PASSWORD '…';
-- GRANT USAGE ON SCHEMA asycuda TO query_tester;
-- GRANT SELECT ON ALL TABLES IN SCHEMA asycuda TO query_tester;   -- includes views
-- (If the underlying AW tables live in another schema, GRANT SELECT there too, or
--  build the views over a read-replica / FDW so the base tables are read-only anyway.)

-- =====================================================================
-- NEXT STEPS
--   1. Fill every -- TODO(instance) using the real physical schema/ERD you
--      obtain (docs/platform/integration.md "What you must request", item 1).
--   2. Extend the ref_* views (Module 1 comment block) for every code table
--      your queries actually join.
--   3. Validate with the customs-query-tester (metadata only): it will confirm
--      each view's column set and that joins resolve — without reading a row.
--   See Sydonia/adapters/README.md for the full workflow and deployment shapes.
-- =====================================================================

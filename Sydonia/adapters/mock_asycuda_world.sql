-- =====================================================================
-- mock_asycuda_world.sql — a MOCK ASYCUDA World physical database.
--
-- Tables in the DOCUMENTED wide/denormalised AW shape (SAD_General_Segment,
-- SAD_Item, SAD_Tax, the UN* reference tables, …) with the same column names
-- the compiler's default mapping (compiler/mappings/asycuda-world.yml) targets.
-- Seeded with the toolbox's end-to-end example (declaration C 427) reshaped
-- into that physical shape.
--
-- Purpose: prove that queries COMPILED from the friendly logical model into
-- genuine Sydonia SQL actually RUN and return correct results — without needing
-- access to a real, non-public ASYCUDA World instance. This is the executable
-- stand-in for a real deployment.
--
--   createdb aw_mock
--   psql -v ON_ERROR_STOP=1 -d aw_mock -f Sydonia/adapters/mock_asycuda_world.sql
--   python -m compiler compile my_logical_query.sql | psql -d aw_mock
-- =====================================================================
BEGIN;
DROP SCHEMA IF EXISTS aw CASCADE;
CREATE SCHEMA aw;
SET search_path TO aw, public;

-- ---- Reference / code tables (UN*, carry validity dates) ----------------
CREATE TABLE UNCTYTAB (CTY_COD varchar(3), CTY_NAM varchar(120), VALID_FROM date, VALID_TO date);
CREATE TABLE UNCUOTAB (CUO_COD varchar(6), CUO_NAM varchar(120), CUO_CTY_COD varchar(3), VALID_FROM date, VALID_TO date);
CREATE TABLE UNTAXTAB (TAX_COD varchar(6), TAX_NAM varchar(120), VALID_FROM date, VALID_TO date);
CREATE TABLE UNOPTAB  (OPR_TIN varchar(20), OPR_NAM varchar(160), OPR_CTY_COD varchar(3));

INSERT INTO UNCTYTAB VALUES
  ('CN','China',DATE '2000-01-01',NULL), ('FM','Micronesia',DATE '2000-01-01',NULL),
  ('SG','Singapore',DATE '2000-01-01',NULL);
INSERT INTO UNCUOTAB VALUES
  ('FMPNI','Pohnpei Customs Office','FM',DATE '2000-01-01',NULL);
INSERT INTO UNTAXTAB VALUES
  ('IMP','Import duty',DATE '2000-01-01',NULL), ('VAT','Value Added Tax',DATE '2000-01-01',NULL);
INSERT INTO UNOPTAB VALUES
  ('EXP001','Shenzhen Electronics Co','CN'), ('IMP001','Pohnpei Trading Ltd','FM'),
  ('BRK001','FSM Customs Brokers','FM');

-- ---- SAD general segment (one row per declaration; PTY_* colour flags) ---
CREATE TABLE SAD_General_Segment (
  INSTANCE_ID   bigint PRIMARY KEY,
  SGS_CUO_COD   varchar(6),  SGS_TYP_COD varchar(4),
  SGS_REG_NBR   integer,      SGS_REG_DAT date,
  SGS_DEC_REF   varchar(35),
  SGS_CNE_COD   varchar(20),  SGS_DCL_COD varchar(20), SGS_EXP_COD varchar(20),
  SGS_CUR_COD   varchar(3),
  SGS_INV_AMT   numeric(18,4), SGS_CIF_AMT numeric(18,4),
  STA           varchar(15),
  PTY_RED char(1), PTY_YEL char(1), PTY_GRE char(1), PTY_BLU char(1)
);
INSERT INTO SAD_General_Segment VALUES
  (1,'FMPNI','IM4',427,DATE '2026-07-06','REF-2026-0001',
   'IMP001','BRK001','EXP001','USD',60000.0000,63300.0000,'released',
   '1','0','0','0');

-- ---- SAD item (HS split across TAR_HSC_NB1..5; VIT_* valuation build-up) --
CREATE TABLE SAD_Item (
  INSTANCE_ID bigint PRIMARY KEY,
  ITM_SGS_ID  bigint,  ITM_NBR smallint,
  TAR_HSC_NB1 varchar(2), TAR_HSC_NB2 varchar(2), TAR_HSC_NB3 varchar(2),
  TAR_HSC_NB4 varchar(2), TAR_HSC_NB5 varchar(2),
  VIT_CIF numeric(18,4), VIT_STV numeric(18,4),
  VIT_FOB numeric(18,4), VIT_FRT numeric(18,4), VIT_INS numeric(18,4),
  ITM_NET_MAS numeric(18,3), ITM_GRS_MAS numeric(18,3),
  ITM_ORG_COD varchar(3), ITM_PKG_NBR numeric(18,3)
);
INSERT INTO SAD_Item VALUES
  (101,1,1,'85','17','12','','',42200.0000,42200.0000,40000.0000,2000.0000,200.0000,1650.000,1800.000,'CN',100),
  (102,1,2,'61','09','10','','',21100.0000,21100.0000,20000.0000,1000.0000,100.0000,2250.000,2400.000,'CN',150);

-- ---- SAD tax (the documented COD/BSE/RAT/AMT/MOP/TYP roots) --------------
CREATE TABLE SAD_Tax (
  INSTANCE_ID bigint PRIMARY KEY, TAX_ITM_ID bigint,
  COD varchar(6), BSE numeric(18,4), RAT numeric(9,4), AMT numeric(18,4),
  MOP varchar(6), TYP char(1)
);
INSERT INTO SAD_Tax VALUES
  (201,101,'IMP',42200.0000, 5.0000,2110.0000,'cash','0'),
  (202,101,'VAT',44310.0000,10.0000,4431.0000,'cash','0'),
  (203,102,'IMP',21100.0000,15.0000,3165.0000,'cash','0'),
  (204,102,'VAT',24265.0000,10.0000,2426.5000,'cash','0');

-- ---- Selectivity + inspection + status log ------------------------------
CREATE TABLE SAD_SELECTIVITY (
  INSTANCE_ID bigint PRIMARY KEY, SEL_SGS_ID bigint,
  SEL_LANE varchar(6), SEL_CRIT varchar(20), SEL_DAT timestamptz, SEL_OFF_ID varchar(40)
);
INSERT INTO SAD_SELECTIVITY VALUES
  (301,1,'RED','HS-HIGHRISK',TIMESTAMPTZ '2026-07-06 10:00+11','cust.aofficer');

CREATE TABLE SEL_PARAM_TAB (SEL_COD varchar(20), SEL_NAM varchar(120), SEL_LANE varchar(6));
INSERT INTO SEL_PARAM_TAB VALUES
  ('HS-HIGHRISK','High-risk commodity chapter','RED'),
  ('NEW-TRADER','First-time importer','YELLOW');

CREATE TABLE INSP_ACT_TAB (
  INSTANCE_ID bigint PRIMARY KEY, INS_SGS_ID bigint,
  INS_RES varchar(20), INS_FND varchar(1000), INS_DAT timestamptz, INS_OFF_ID varchar(40)
);
INSERT INTO INSP_ACT_TAB VALUES
  (401,1,'conform','Goods conform to declaration',TIMESTAMPTZ '2026-07-06 10:30+11','cust.aofficer');

CREATE TABLE SAD_STATUS_LOG (
  INSTANCE_ID bigint PRIMARY KEY, LOG_SGS_ID bigint,
  LOG_STA varchar(15), LOG_DAT timestamptz, LOG_USR varchar(40), LOG_NOTE varchar(200)
);
INSERT INTO SAD_STATUS_LOG VALUES
  (501,1,'stored',    TIMESTAMPTZ '2026-07-06 08:00+11','broker.jdoe','Draft captured'),
  (502,1,'registered',TIMESTAMPTZ '2026-07-06 09:00+11','broker.jdoe','Registered C 427'),
  (503,1,'assessed',  TIMESTAMPTZ '2026-07-06 09:30+11','broker.jdoe','Assessed'),
  (504,1,'paid',      TIMESTAMPTZ '2026-07-06 11:00+11','broker.jdoe','Paid'),
  (505,1,'released',  TIMESTAMPTZ '2026-07-06 12:00+11','cust.aofficer','Released');

COMMIT;

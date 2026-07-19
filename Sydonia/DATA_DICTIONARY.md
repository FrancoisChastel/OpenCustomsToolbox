# DATA_DICTIONARY.md — every table & column

Generated from the loaded PostgreSQL catalog (`asycuda` schema) so it matches `schema/asycuda.sql`
exactly. **Source** = the table-level provenance tag from the DDL (`src: <ID>` resolves in SOURCES.md;
official UNCTAD/DTL table docs are S013–S016; `inferred` = modelling judgement, see COVERAGE.md).
Total tables: 55.


## Module: REFERENCE / CONFIGURATION (GOAL §4.1)

### `ref_country`
*Source:* `src: S013, S008`  
*Purpose:* ISO 3166 countries; used for origin, export, destination, nationality (S008).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| iso_alpha2 | character varying(2) | NOT NULL |  |
| iso_alpha3 | character varying(3) | nullable |  |
| numeric_code | character varying(3) | nullable |  |
| name | character varying(100) | NOT NULL |  |
| is_active | boolean | NOT NULL |  |

### `ref_currency`
*Source:* `src: S013, S008`  
*Purpose:* ISO 4217 currencies for invoice / freight / insurance values (S008, S003 box 22).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| iso_code | character varying(3) | NOT NULL |  |
| numeric_code | character varying(3) | nullable |  |
| name | character varying(80) | NOT NULL |  |
| minor_units | smallint | NOT NULL |  |
| is_active | boolean | NOT NULL |  |

### `ref_exchange_rate`
*Source:* `src: S013`  
*Purpose:* Exchange rate applied to convert invoice currency (SAD box 23); table shape inferred.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| currency_id | bigint | NOT NULL |  |
| rate | numeric(18,6) | NOT NULL |  |
| valid_from | date | NOT NULL |  |
| valid_to | date | nullable |  |

### `ref_customs_office`
*Source:* `src: S013, S008`  
*Purpose:* Customs offices (S008 customs_office_code AN5; S003 office of entry box 29).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| office_code | character varying(5) | NOT NULL |  |
| name | character varying(120) | NOT NULL |  |
| country_id | bigint | nullable |  |
| is_active | boolean | NOT NULL |  |

### `ref_location`
*Source:* `src: S013, S008`  
*Purpose:* UN/LOCODE places/ports of loading, unloading, departure, destination (S008).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| unlocode | character varying(5) | NOT NULL |  |
| name | character varying(120) | NOT NULL |  |
| country_id | bigint | nullable |  |
| is_port | boolean | NOT NULL |  |

### `ref_transport_mode`
*Source:* `src: S013, S008`  
*Purpose:* Mode of transport 1=Sea 2=Rail 3=Road 4=Air 5=Postal 6=Multimodal 7=Fixed 8=Inland waterways 9=Unknown (S008).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(3) | NOT NULL |  |
| name | character varying(40) | NOT NULL |  |

### `ref_package_type`
*Source:* `src: S013, S008`  
*Purpose:* Kind-of-packages codes, UN/ECE Rec 21 alpha-2 (S008 package_type_code; S003 box 31).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(2) | NOT NULL |  |
| name | character varying(80) | NOT NULL |  |

### `ref_container_type`
*Source:* `src: S013, S008`  
*Purpose:* Container size-type per ISO 6346:1995 (S008 type_of_container).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(4) | NOT NULL |  |
| name | character varying(80) | NOT NULL |  |

### `ref_unit_of_measure`
*Source:* `src: S013`  
*Purpose:* Units for supplementary quantity / statistical units (SAD box 41, S003); values inferred.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(6) | NOT NULL |  |
| name | character varying(60) | NOT NULL |  |

### `ref_incoterm`
*Source:* `src: S013, S003, S012`  
*Purpose:* Incoterms delivery-terms codes (SAD box 20, S003; S012).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(3) | NOT NULL |  |
| name | character varying(60) | NOT NULL |  |
| edition | character varying(9) | nullable |  |

### `ref_hs_tariff`
*Source:* `src: S013, S003`  
*Purpose:* Harmonized System commodity codes with self-referential hierarchy (SAD box 33, S003; S008 HS 6-digit).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| hs_code | character varying(12) | NOT NULL |  |
| parent_id | bigint | nullable |  |
| description | character varying(400) | NOT NULL |  |
| uom_id | bigint | nullable |  |
| is_active | boolean | NOT NULL |  |

### `ref_cpc_regime`
*Source:* `src: S013, S003`  
*Purpose:* Customs Procedure Codes / regimes (SAD box 37, S003): requested(2)+previous(2) extended code.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| cpc_code | character varying(7) | NOT NULL |  |
| name | character varying(120) | NOT NULL |  |
| regime_group | character varying(30) | nullable |  |
| is_suspense | boolean | NOT NULL |  |
| is_active | boolean | NOT NULL |  |

### `ref_tax_type`
*Source:* `src: S013, S003`  
*Purpose:* Duty/tax/fee types calculated per item (SAD box 47, S003).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(6) | NOT NULL |  |
| name | character varying(80) | NOT NULL |  |
| is_ad_valorem | boolean | NOT NULL |  |

### `ref_tax_rate`
*Source:* `src: S013`  
*Purpose:* Applicable rate per tax type / commodity / regime / origin (SAD box 47 implies rates); table shape inferred.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| tax_type_id | bigint | NOT NULL |  |
| hs_id | bigint | nullable |  |
| cpc_id | bigint | nullable |  |
| origin_id | bigint | nullable |  |
| rate_percent | numeric(9,4) | nullable |  |
| specific_amount | numeric(18,4) | nullable |  |
| valid_from | date | NOT NULL |  |
| valid_to | date | nullable |  |

### `ref_document_type`
*Source:* `src: S013, S003, S008`  
*Purpose:* Attached/supporting document types (SAD box 44, S003; S008 attached_document_code).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(6) | NOT NULL |  |
| name | character varying(120) | NOT NULL |  |

### `ref_exemption_code`
*Source:* `src: S013, S003`  
*Purpose:* Additional National Codes granting special duty/tax treatment (SAD box 37 national procedure, S003).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(6) | NOT NULL |  |
| name | character varying(120) | NOT NULL |  |
| description | character varying(300) | nullable |  |

### `ref_declaration_type`
*Source:* `src: S013, S003`  
*Purpose:* Declaration type codes (SAD box 1, S003): first letters model, digit = extended procedure.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(4) | NOT NULL |  |
| name | character varying(80) | NOT NULL |  |
| direction | character varying(10) | NOT NULL |  |

### `ref_declaration_status`
*Source:* `src: S014, S002`  
*Purpose:* Declaration lifecycle: stored->registered->assessed->paid->released (+queried/cancelled) (S002).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(15) | NOT NULL |  |
| name | character varying(60) | NOT NULL |  |
| sort_order | smallint | NOT NULL |  |

### `ref_manifest_status`
*Source:* `src: S015`  
*Purpose:* Manifest lifecycle (stored/registered/amended/closed); inferred from S006/S011 workflow.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(15) | NOT NULL |  |
| name | character varying(60) | NOT NULL |  |
| sort_order | smallint | NOT NULL |  |

### `ref_bl_nature`
*Source:* `src: S013, S008`  
*Purpose:* Transport-document nature codes (S008 Bol_nature).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(2) | NOT NULL |  |
| name | character varying(60) | NOT NULL |  |

### `ref_selectivity_lane`
*Source:* `src: S014, S002, S005`  
*Purpose:* Selectivity lanes green/yellow/red/blue (S002, S005).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(6) | NOT NULL |  |
| name | character varying(40) | NOT NULL |  |
| requires_exam | boolean | NOT NULL |  |
| description | character varying(200) | nullable |  |


## Module: TRADERS & SYSTEM USERS (GOAL §4.1)

### `trader`
*Source:* `src: S013, S003, S008`  
*Purpose:* Economic operators: importer/exporter/consignee/declarant/broker/carrier, keyed by TIN (S003, S008).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| tin | character varying(20) | NOT NULL |  |
| name | character varying(140) | NOT NULL |  |
| address | character varying(200) | nullable |  |
| country_id | bigint | nullable |  |
| is_active | boolean | NOT NULL |  |

### `trader_role`
*Source:* `inferred`  
*Purpose:* Roles a trader may act in; inferred normalisation of the single trader/economic-operator concept.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| trader_id | bigint | NOT NULL |  |
| role | character varying(20) | NOT NULL |  |

### `sys_user`
*Source:* `src: S002`  
*Purpose:* System users (customs staff, brokers, traders); registration required (S002).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| login_name | character varying(40) | NOT NULL |  |
| full_name | character varying(120) | NOT NULL |  |
| trader_id | bigint | nullable |  |
| office_id | bigint | nullable |  |
| is_active | boolean | NOT NULL |  |

### `sys_role`
*Source:* `inferred`  
*Purpose:* RBAC roles; inferred (ASYCUDA World has role-based menus but no public schema).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(30) | NOT NULL |  |
| name | character varying(80) | NOT NULL |  |

### `sys_permission`
*Source:* `inferred`  
*Purpose:* RBAC permissions; inferred.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(40) | NOT NULL |  |
| name | character varying(120) | NOT NULL |  |

### `sys_user_role`
*Source:* `inferred`  

| Column | Type | Null | Notes |
|--------|------|------|-------|
| user_id | bigint | NOT NULL |  |
| role_id | bigint | NOT NULL |  |

### `sys_role_permission`
*Source:* `inferred`  

| Column | Type | Null | Notes |
|--------|------|------|-------|
| role_id | bigint | NOT NULL |  |
| permission_id | bigint | NOT NULL |  |


## Module: MANIFEST / CARGO (GOAL §4.2)

### `manifest`
*Source:* `src: S015, S008, S006`  
*Purpose:* Cargo manifest general segment: carrier, voyage, ports, dates, totals, office (S008, S006).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| office_id | bigint | NOT NULL |  |
| manifest_year | smallint | NOT NULL |  |
| registration_number | integer | nullable |  |
| voyage_number | character varying(17) | NOT NULL |  |
| transport_mode_id | bigint | NOT NULL |  |
| identity_of_transport | character varying(40) | nullable |  |
| nationality_id | bigint | nullable |  |
| registration_ref | character varying(35) | nullable |  |
| master_name | character varying(70) | nullable |  |
| carrier_id | bigint | nullable |  |
| shipping_agent_id | bigint | nullable |  |
| place_departure_id | bigint | nullable |  |
| place_destination_id | bigint | nullable |  |
| date_of_departure | date | nullable |  |
| date_of_arrival | date | nullable |  |
| date_of_last_discharge | date | nullable |  |
| total_bols | integer | nullable |  |
| total_packages | numeric(18,3) | nullable |  |
| total_containers | integer | nullable |  |
| total_gross_mass | numeric(18,3) | nullable |  |
| tonnage_net | numeric(18,3) | nullable |  |
| tonnage_gross | numeric(18,3) | nullable |  |
| status_id | bigint | nullable |  |
| created_at | timestamp with time zone | NOT NULL |  |

### `bill_of_lading`
*Source:* `src: S015, S008, S006`  
*Purpose:* Transport document (B/L/AWB). House B/L = a consignment; master_bl_id models consolidation/degroupage (S008, S006, S010).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| manifest_id | bigint | NOT NULL |  |
| line_number | integer | NOT NULL |  |
| bl_reference | character varying(35) | NOT NULL |  |
| bl_nature_id | bigint | NOT NULL |  |
| bl_type_code | character varying(3) | nullable |  |
| is_master | boolean | NOT NULL |  |
| master_bl_id | bigint | nullable |  |
| exporter_id | bigint | nullable |  |
| consignee_id | bigint | nullable |  |
| notify_id | bigint | nullable |  |
| place_loading_id | bigint | nullable |  |
| place_unloading_id | bigint | nullable |  |
| number_of_packages | numeric(18,3) | nullable |  |
| package_type_id | bigint | nullable |  |
| gross_mass | numeric(18,3) | nullable |  |
| goods_description | character varying(2000) | nullable |  |
| volume_m3 | numeric(18,3) | nullable |  |
| freight_indicator | character varying(2) | nullable |  |
| freight_value | numeric(18,4) | nullable |  |
| freight_currency_id | bigint | nullable |  |
| customs_value | numeric(18,4) | nullable |  |
| insurance_value | numeric(18,4) | nullable |  |

### `container`
*Source:* `src: S015, S008`  
*Purpose:* Containers per B/L; reference/size-type follow ISO 6346 (S008 ctn_segment).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| bl_id | bigint | NOT NULL |  |
| ctn_reference | character varying(17) | NOT NULL |  |
| container_type_id | bigint | nullable |  |
| number_of_packages | integer | nullable |  |
| empty_full | character varying(10) | nullable |  |
| seal1 | character varying(10) | nullable |  |
| seal2 | character varying(10) | nullable |  |
| empty_weight | numeric(18,3) | nullable |  |
| goods_weight | numeric(18,3) | nullable |  |
| volume_m3 | numeric(18,3) | nullable |  |
| dangerous_goods_code | character varying(10) | nullable |  |
| goods_description | character varying(500) | nullable |  |

### `manifest_cargo_item`
*Source:* `src: S015, S008`  
*Purpose:* Goods/commodity lines within a transport document (S008 Goods_segment/Commodity_Segment).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| bl_id | bigint | NOT NULL |  |
| line_number | integer | NOT NULL |  |
| hs_code | character varying(6) | nullable |  |
| goods_description | character varying(500) | NOT NULL |  |
| number_of_packages | numeric(18,3) | nullable |  |
| package_type_id | bigint | nullable |  |
| gross_mass | numeric(18,3) | nullable |  |
| container_id | bigint | nullable |  |

### `manifest_status_history`
*Source:* `inferred`  
*Purpose:* Manifest status transitions; inferred lifecycle table.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| manifest_id | bigint | NOT NULL |  |
| status_id | bigint | NOT NULL |  |
| changed_at | timestamp with time zone | NOT NULL |  |
| changed_by | bigint | nullable |  |
| note | character varying(200) | nullable |  |


## Module: DECLARATION (THE SAD) (GOAL §4.3)

### `declaration`
*Source:* `src: S014, S003, S001`  
*Purpose:* SAD general segment — one per consignment: parties, regime, transport, invoice totals, status, selectivity (S003 boxes 1-49/B, S001).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| office_id | bigint | NOT NULL |  |
| declaration_type_id | bigint | NOT NULL |  |
| cpc_id | bigint | nullable |  |
| registration_serial | character varying(2) | nullable |  |
| registration_number | integer | nullable |  |
| registration_date | date | nullable |  |
| trader_reference | character varying(35) | nullable |  |
| exporter_id | bigint | nullable |  |
| consignee_id | bigint | nullable |  |
| declarant_id | bigint | nullable |  |
| financial_id | bigint | nullable |  |
| country_export_id | bigint | nullable |  |
| country_origin_id | bigint | nullable |  |
| country_destination_id | bigint | nullable |  |
| country_last_consign_id | bigint | nullable |  |
| trading_country_id | bigint | nullable |  |
| incoterm_id | bigint | nullable |  |
| delivery_place | character varying(120) | nullable |  |
| transport_mode_border_id | bigint | nullable |  |
| transport_mode_inland_id | bigint | nullable |  |
| border_transport_identity | character varying(60) | nullable |  |
| place_of_discharge_id | bigint | nullable |  |
| total_items | smallint | nullable |  |
| total_packages | numeric(18,3) | nullable |  |
| currency_id | bigint | nullable |  |
| total_invoice_amount | numeric(18,4) | nullable |  |
| exchange_rate | numeric(18,6) | nullable |  |
| total_freight | numeric(18,4) | nullable |  |
| total_insurance | numeric(18,4) | nullable |  |
| total_cif_value | numeric(18,4) | nullable |  |
| selectivity_lane_id | bigint | nullable |  |
| status_id | bigint | NOT NULL |  |
| assessment_number | character varying(20) | nullable |  |
| assessment_date | date | nullable |  |
| manifest_id | bigint | nullable |  |
| created_by | bigint | nullable |  |
| created_at | timestamp with time zone | NOT NULL |  |

### `declaration_item`
*Source:* `src: S014, S003`  
*Purpose:* SAD item segment (boxes 31-49): commodity, origin, mass, procedure, valuation, statistical value = tax base (S003).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| declaration_id | bigint | NOT NULL |  |
| item_number | smallint | NOT NULL |  |
| hs_id | bigint | nullable |  |
| hs_code | character varying(12) | NOT NULL |  |
| goods_description | character varying(500) | nullable |  |
| country_origin_id | bigint | nullable |  |
| cpc_id | bigint | nullable |  |
| national_procedure | character varying(3) | nullable |  |
| exemption_id | bigint | nullable |  |
| preference_code | character varying(3) | nullable |  |
| number_of_packages | numeric(18,3) | nullable |  |
| package_type_id | bigint | nullable |  |
| marks_and_numbers | character varying(200) | nullable |  |
| container_reference | character varying(17) | nullable |  |
| gross_mass | numeric(18,3) | nullable |  |
| net_mass | numeric(18,3) | nullable |  |
| supplementary_qty | numeric(18,3) | nullable |  |
| supplementary_uom_id | bigint | nullable |  |
| item_price | numeric(18,4) | nullable |  |
| valuation_method_code | character varying(3) | nullable |  |
| adjustment_indicator | numeric(9,4) | nullable |  |
| statistical_value | numeric(18,4) | nullable |  |
| customs_value | numeric(18,4) | nullable |  |
| quota | character varying(20) | nullable |  |
| warehouse_id | bigint | nullable |  |
| warehouse_days | integer | nullable |  |

### `valuation_note`
*Source:* `src: S003, S017`  
*Purpose:* Declaration-level value build-up: freight + insurance + other -> CIF customs value (S003 valuation note).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| declaration_id | bigint | NOT NULL |  |
| invoice_currency_id | bigint | nullable |  |
| total_invoice_fob | numeric(18,4) | nullable |  |
| external_freight | numeric(18,4) | nullable |  |
| internal_freight | numeric(18,4) | nullable |  |
| insurance | numeric(18,4) | nullable |  |
| other_costs | numeric(18,4) | nullable |  |
| total_cif | numeric(18,4) | nullable |  |

### `item_value_note`
*Source:* `src: S014, S003`  
*Purpose:* Freight/insurance apportioned per item to produce item CIF, the tax base (S003 valuation note; box 46).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| declaration_item_id | bigint | NOT NULL |  |
| item_fob | numeric(18,4) | nullable |  |
| apportioned_freight | numeric(18,4) | nullable |  |
| apportioned_insurance | numeric(18,4) | nullable |  |
| apportioned_other | numeric(18,4) | nullable |  |
| item_cif | numeric(18,4) | nullable |  |

### `declaration_tax_line`
*Source:* `src: S014, S003`  
*Purpose:* Per-item per-tax calculation: base, rate, amount, mode of payment (SAD box 47, S003).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| declaration_item_id | bigint | NOT NULL |  |
| tax_type_id | bigint | NOT NULL |  |
| tax_base | numeric(18,4) | NOT NULL |  |
| rate_percent | numeric(9,4) | nullable |  |
| specific_amount | numeric(18,4) | nullable |  |
| tax_amount | numeric(18,4) | NOT NULL |  |
| mode_of_payment | character varying(6) | nullable |  |
| is_manual | boolean | NOT NULL |  |

### `declaration_attached_document`
*Source:* `src: S014, S003, S008`  
*Purpose:* Attached/supporting documents at header or item level (SAD box 44, S003; S008).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| declaration_id | bigint | NOT NULL |  |
| declaration_item_id | bigint | nullable |  |
| document_type_id | bigint | NOT NULL |  |
| document_reference | character varying(60) | nullable |  |
| document_date | date | nullable |  |

### `declaration_previous_document`
*Source:* `src: S014, S003, S008`  
*Purpose:* SAD box 40: links items to the manifest B/L or a previous declaration (write-off) (S003, S008).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| declaration_id | bigint | NOT NULL |  |
| declaration_item_id | bigint | nullable |  |
| bl_id | bigint | nullable |  |
| prev_declaration_id | bigint | nullable |  |
| reference | character varying(60) | nullable |  |
| written_off_packages | numeric(18,3) | nullable |  |
| written_off_mass | numeric(18,3) | nullable |  |

### `declaration_status_history`
*Source:* `src: S014, S002`  
*Purpose:* Declaration status transitions over its lifecycle (S002).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| declaration_id | bigint | NOT NULL |  |
| status_id | bigint | NOT NULL |  |
| changed_at | timestamp with time zone | NOT NULL |  |
| changed_by | bigint | nullable |  |
| note | character varying(200) | nullable |  |


## Module: SELECTIVITY / RISK (GOAL §4.6)

### `risk_criterion`
*Source:* `src: S014`  
*Purpose:* Risk/selectivity criteria driving lane assignment; inferred (S002 references criteria, no public schema).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(20) | NOT NULL |  |
| name | character varying(120) | NOT NULL |  |
| target_lane_id | bigint | nullable |  |
| is_active | boolean | NOT NULL |  |

### `selectivity_result`
*Source:* `src: S014, S002, S005`  
*Purpose:* Lane assigned to a declaration when selectivity is triggered (S002, S005).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| declaration_id | bigint | NOT NULL |  |
| lane_id | bigint | NOT NULL |  |
| criterion_id | bigint | nullable |  |
| triggered_at | timestamp with time zone | NOT NULL |  |
| officer_id | bigint | nullable |  |
| note | character varying(300) | nullable |  |

### `inspection_act`
*Source:* `src: S014, S002, S005`  
*Purpose:* Inspection/examination act for red/yellow declarations, feeding release (S002, S005).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| declaration_id | bigint | NOT NULL |  |
| officer_id | bigint | nullable |  |
| inspected_at | timestamp with time zone | nullable |  |
| result | character varying(20) | nullable |  |
| findings | character varying(1000) | nullable |  |


## Module: ACCOUNTING (GOAL §4.4)

### `account`
*Source:* `src: S016, S003`  
*Purpose:* Trader deferred-payment/credit/prepayment accounts (SAD box 48, S003).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| account_number | character varying(20) | NOT NULL |  |
| trader_id | bigint | nullable |  |
| account_type | character varying(20) | NOT NULL |  |
| currency_id | bigint | nullable |  |
| balance | numeric(18,4) | NOT NULL |  |
| is_active | boolean | NOT NULL |  |

### `payment`
*Source:* `src: S016, S003, S005`  
*Purpose:* Payment of assessed amount, cash or against an account (S003 box B, S005).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| declaration_id | bigint | NOT NULL |  |
| account_id | bigint | nullable |  |
| amount | numeric(18,4) | NOT NULL |  |
| currency_id | bigint | nullable |  |
| mode_of_payment | character varying(20) | NOT NULL |  |
| paid_at | timestamp with time zone | NOT NULL |  |
| paid_by | bigint | nullable |  |

### `receipt`
*Source:* `src: S016, S003`  
*Purpose:* Receipt issued on payment of a declaration (SAD box B, S003).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| payment_id | bigint | NOT NULL |  |
| receipt_number | character varying(20) | NOT NULL |  |
| receipt_date | date | NOT NULL |  |
| total_amount | numeric(18,4) | NOT NULL |  |

### `account_movement`
*Source:* `src: S016`  
*Purpose:* Ledger movements against an account; inferred.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| account_id | bigint | NOT NULL |  |
| payment_id | bigint | nullable |  |
| movement_type | character varying(10) | NOT NULL |  |
| amount | numeric(18,4) | NOT NULL |  |
| balance_after | numeric(18,4) | nullable |  |
| moved_at | timestamp with time zone | NOT NULL |  |

### `guarantee`
*Source:* `src: S019, S003`  
*Purpose:* Security/guarantee for suspense regimes (SAD box 52 references it, S003); table shape inferred.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| reference | character varying(30) | NOT NULL |  |
| trader_id | bigint | nullable |  |
| guarantee_type | character varying(20) | nullable |  |
| amount | numeric(18,4) | NOT NULL |  |
| currency_id | bigint | nullable |  |
| valid_from | date | nullable |  |
| valid_to | date | nullable |  |
| is_active | boolean | NOT NULL |  |


## Module: TRANSIT & SUSPENSE (GOAL §4.5)

### `transit_declaration`
*Source:* `src: S014, S019, S003`  
*Purpose:* Transit declaration extension: principal, offices, guarantee, itinerary (SAD boxes 50-53, S003).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| declaration_id | bigint | NOT NULL |  |
| principal_id | bigint | nullable |  |
| office_departure_id | bigint | nullable |  |
| office_transit_id | bigint | nullable |  |
| office_destination_id | bigint | nullable |  |
| guarantee_id | bigint | nullable |  |
| itinerary | character varying(300) | nullable |  |
| seals_affixed | character varying(200) | nullable |  |
| time_limit_date | date | nullable |  |

### `ref_warehouse`
*Source:* `src: S013, S019, S003`  
*Purpose:* Customs/bonded warehouses (SAD box 49 warehouse identification, S003).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| code | character varying(10) | NOT NULL |  |
| name | character varying(120) | NOT NULL |  |
| office_id | bigint | nullable |  |
| keeper_id | bigint | nullable |  |
| is_active | boolean | NOT NULL |  |

### `warehouse_entry`
*Source:* `src: S014, S019`  
*Purpose:* Goods placed under warehousing regime; inferred from S003 box 49 suspense.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| warehouse_id | bigint | NOT NULL |  |
| declaration_id | bigint | nullable |  |
| entry_date | date | NOT NULL |  |
| packages | numeric(18,3) | nullable |  |
| gross_mass | numeric(18,3) | nullable |  |

### `warehouse_exit`
*Source:* `src: S014, S019`  
*Purpose:* Removal of goods from warehouse (write-off); inferred.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| warehouse_entry_id | bigint | NOT NULL |  |
| declaration_id | bigint | nullable |  |
| exit_date | date | NOT NULL |  |
| packages | numeric(18,3) | nullable |  |
| gross_mass | numeric(18,3) | nullable |  |

### `temporary_admission`
*Source:* `src: S019`  
*Purpose:* Temporary admission suspense regime with time limit and re-export link; inferred (S003 box 49).

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| declaration_id | bigint | NOT NULL |  |
| guarantee_id | bigint | nullable |  |
| time_limit_date | date | nullable |  |
| re_export_declaration_id | bigint | nullable |  |


## Module: AUDIT / WORKFLOW (cross-cutting) (GOAL §4.7)

### `audit_log`
*Source:* `src: S013`  
*Purpose:* Cross-cutting who/what/when audit trail; inferred.

| Column | Type | Null | Notes |
|--------|------|------|-------|
| id | bigint | NOT NULL |  |
| entity_name | character varying(60) | NOT NULL |  |
| entity_id | bigint | nullable |  |
| action | character varying(20) | NOT NULL |  |
| actor_id | bigint | nullable |  |
| occurred_at | timestamp with time zone | NOT NULL |  |
| detail | character varying(1000) | nullable |  |

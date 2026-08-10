-- =====================================================================
-- 02_stage_and_copy.sql  --  Stage interne + COPY INTO vers AW_SOURCE
--
-- Prerequis : la DDL des 27 tables AW_SOURCE (types permissifs VARCHAR, ordre
-- des colonnes EXACT transcrit depuis instawdb.sql). Patron ci-dessous.
-- =====================================================================

use role dbt_role;
use warehouse compute_wh;
use schema aw_source.raw;

-- --------------------------------------------------------------------
-- 1. Stage interne + upload des fichiers
-- --------------------------------------------------------------------
create stage if not exists aw_stage
    file_format = ff_aw_tsv_utf8;

-- Depuis SnowSQL (les fichiers sont petits, ~150 Mo au total) :
--   PUT file://.../data/*.csv @aw_stage AUTO_COMPRESS=TRUE;
-- list @aw_stage;

-- --------------------------------------------------------------------
-- 2. Patron DDL "landing" permissif (a repeter pour les 27 tables)
--    Ordre des colonnes = seul contrat (fichiers sans en-tete).
--    Tout en VARCHAR : le typage est le travail de silver (dbt).
-- --------------------------------------------------------------------
create schema if not exists aw_source.sales;

create or replace table aw_source.sales.salesorderheader (
    salesorderid varchar, revisionnumber varchar, orderdate varchar,
    duedate varchar, shipdate varchar, status varchar, onlineorderflag varchar,
    salesordernumber varchar, purchaseordernumber varchar, accountnumber varchar,
    customerid varchar, salespersonid varchar, territoryid varchar,
    billtoaddressid varchar, shiptoaddressid varchar, shipmethodid varchar,
    creditcardid varchar, creditcardapprovalcode varchar, currencyrateid varchar,
    subtotal varchar, taxamt varchar, freight varchar, totaldue varchar,
    comment varchar, rowguid varchar, modifieddate varchar
);
-- ... transcrire de la meme facon : salesorderdetail, customer, store,
--     salesperson, salespersonquotahistory, salesterritory, specialoffer,
--     specialofferproduct, creditcard, currency, currencyrate,
--     salesorderheadersalesreason, salesreason (schema SALES) ;
--     product, productsubcategory, productcategory, productmodel,
--     productcosthistory, productlistpricehistory (schema PRODUCTION) ;
--     person, address, stateprovince, countryregion, businessentityaddress
--     (schema PERSON) ; employee (HUMANRESOURCES) ; shipmethod (PURCHASING).

-- --------------------------------------------------------------------
-- 3. Patron COPY INTO (a generer par script plutot qu'a la main)
--    ON_ERROR = ABORT_STATEMENT : echouer bruyamment, ne jamais sauter de ligne.
-- --------------------------------------------------------------------
copy into aw_source.sales.salesorderheader
    from @aw_stage/SalesOrderHeader.csv
    file_format = (format_name = ff_aw_tsv_utf8)
    on_error = 'abort_statement';

-- Fichiers UTF-16 (Person, Store, ...) : utiliser ff_aw_tsv_utf16.
-- copy into aw_source.person.person
--     from @aw_stage/Person.csv
--     file_format = (format_name = ff_aw_tsv_utf16)
--     on_error = 'abort_statement';

-- Debug sans charger :
--   copy into ... validation_mode = 'RETURN_ERRORS';

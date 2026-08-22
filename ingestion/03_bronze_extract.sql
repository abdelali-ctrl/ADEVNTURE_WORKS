-- =====================================================================
-- 03_bronze_extract.sql  --  AW_SOURCE  →  BRONZE (OLTP.<schema>)
--
-- Ajoute les metadonnees de chargement (_loaded_at, _source_file, _batch_id) et
-- applique le CUTOFF de la Semaine 1. Le bronze OLTP.* est ce que dbt lit.
--
-- IDEMPOTENCE : `create or replace ... as select` reconstruit la table de facon
-- deterministe → rejouer le script donne des comptages identiques (0 doublon).
-- Pour un vrai delta (Semaine 3), voir le bloc MERGE en bas.
-- =====================================================================

use role dbt_role;
use warehouse compute_wh;

-- Parametres du batch
set cutoff   = '2013-12-31';                      -- Semaine 1 ; passer a CURRENT_DATE pour le delta 2014
set batch_id = 'init_' || to_varchar(current_timestamp(), 'YYYYMMDD_HH24MISS');

create database if not exists oltp;
create schema if not exists oltp.sales;
create schema if not exists oltp.production;

-- --------------------------------------------------------------------
-- Tables filtrees par le cutoff (grain commande)
-- --------------------------------------------------------------------
create or replace table oltp.sales.salesorderheader as
select
    s.*,
    current_timestamp()      as _loaded_at,
    'SalesOrderHeader.csv'   as _source_file,
    $batch_id                as _batch_id
from aw_source.sales.salesorderheader s
where try_to_date(s.orderdate) <= $cutoff;

-- Les lignes ne sont conservees que pour les commandes retenues (coherence referentielle)
create or replace table oltp.sales.salesorderdetail as
select
    d.*,
    current_timestamp()      as _loaded_at,
    'SalesOrderDetail.csv'   as _source_file,
    $batch_id                as _batch_id
from aw_source.sales.salesorderdetail d
where d.salesorderid in (
    select salesorderid from oltp.sales.salesorderheader
);

-- --------------------------------------------------------------------
-- Tables de reference chargees en entier (patron a repeter)
-- --------------------------------------------------------------------
create or replace table oltp.production.product as
select
    p.*,
    current_timestamp()  as _loaded_at,
    'Product.csv'        as _source_file,
    $batch_id            as _batch_id
from aw_source.production.product p;

-- ... repeter pour les 24 autres tables (customer, store, salesperson,
--     salespersonquotahistory, salesterritory, specialoffer, creditcard,
--     currency, currencyrate, salesorderheadersalesreason, salesreason,
--     productsubcategory, productcategory, productmodel, productcosthistory,
--     productlistpricehistory, person, address, stateprovince, countryregion,
--     businessentityaddress, employee, shipmethod).

-- --------------------------------------------------------------------
-- Variante DELTA idempotente (Semaine 3) — au lieu de create or replace :
--   MERGE sur la cle naturelle avec un watermark, pour n'ajouter que le neuf.
-- --------------------------------------------------------------------
-- merge into oltp.sales.salesorderheader tgt
-- using (
--     select *, current_timestamp() as _loaded_at, 'SalesOrderHeader.csv' as _source_file, $batch_id as _batch_id
--     from aw_source.sales.salesorderheader
--     where try_to_date(orderdate) <= $cutoff
--       and try_to_timestamp(modifieddate) > (select coalesce(max(try_to_timestamp(modifieddate)), '1900-01-01') from oltp.sales.salesorderheader)
-- ) src
-- on tgt.salesorderid = src.salesorderid
-- when matched then update set ...
-- when not matched then insert ...;

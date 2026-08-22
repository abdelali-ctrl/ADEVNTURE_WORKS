-- =====================================================================
-- 04_reconcile.sql  --  Controles de reconciliation apres chargement
-- A reporter dans docs/load_reconciliation.md.
-- =====================================================================

use role dbt_role;
use warehouse compute_wh;

-- 1. AW_SOURCE : comptages vs `wc -l` des fichiers (doivent correspondre exactement)
select 'salesorderheader' as tbl, count(*) as n from aw_source.sales.salesorderheader
union all select 'salesorderdetail', count(*) from aw_source.sales.salesorderdetail
union all select 'product', count(*) from aw_source.production.product;
-- ... etendre aux 27 tables.

-- 2. Effet du cutoff : combien de commandes retenues pour le delta 2014 ?
select
    count_if(try_to_date(orderdate) <= '2013-12-31') as bronze_initial,
    count_if(try_to_date(orderdate) >  '2013-12-31') as delta_2014_en_attente,
    count(*)                                          as total_source
from aw_source.sales.salesorderheader;

-- 3. Idempotence : rejouer 03_bronze_extract.sql puis verifier que ca ne bouge pas
select count(*) as bronze_header_rows from oltp.sales.salesorderheader;
select count(*) as bronze_detail_rows from oltp.sales.salesorderdetail;

-- 4. Metadonnees presentes sur chaque table bronze
select distinct _batch_id, _source_file, min(_loaded_at) as first_loaded
from oltp.sales.salesorderheader group by 1, 2;

-- 5. Plage de dates (doit couvrir ~mi-2011 → 2013-12-31 apres cutoff)
select min(try_to_date(orderdate)) as min_order, max(try_to_date(orderdate)) as max_order
from oltp.sales.salesorderheader;

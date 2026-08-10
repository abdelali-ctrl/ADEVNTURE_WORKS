{{ config(materialized='table') }}

/*
    dim_product — SCD Type 2 (cahier §5.2).
    Alimentee par le snapshot `snap_product` : une ligne par version de produit,
    avec valid_from / valid_to / is_current. La cle de substitution est au grain
    version. Le fait joint en point-in-time (order_date entre valid_from/valid_to)
    pour retrouver la version en vigueur a la date de commande.

    Note : la 1ere version de chaque produit voit son valid_from ramene a
    1900-01-01 pour couvrir tout l'historique anterieur a la capture du snapshot
    (sinon les commandes 2011-2014 ne matcheraient aucune version).
*/

with versions as (
    select
        *,
        min(dbt_valid_from) over (partition by product_id) as first_valid_from
    from {{ ref('snap_product') }}
),

subcategory as (select * from {{ ref('stg_productsubcat') }}),
category as (select * from {{ ref('stg_productcategory') }})

select
    {{ dbt_utils.generate_surrogate_key(['v.product_id', 'v.dbt_valid_from']) }} as sk_product,
    v.product_id,
    v.product_name,
    v.product_number,
    v.standard_cost,
    v.list_price,
    sc.product_subcategory_name as subcategory_name,
    c.product_category_name     as category_name,

    case when v.dbt_valid_from = v.first_valid_from
         then '1900-01-01'::timestamp
         else v.dbt_valid_from end          as valid_from,
    coalesce(v.dbt_valid_to, '9999-12-31'::timestamp) as valid_to,
    (v.dbt_valid_to is null)                as is_current,
    v.modified_date
from versions v
left join subcategory sc on v.subcategory_id = sc.product_subcategory_id
left join category c on sc.product_category_id = c.product_category_id

union all

-- Membre inconnu (§5.4)
select
    '-1'                    as sk_product,
    -1                     as product_id,
    'Unknown'             as product_name,
    'Unknown'             as product_number,
    0                     as standard_cost,
    0                     as list_price,
    'Unknown'             as subcategory_name,
    'Unknown'             as category_name,
    '1900-01-01'::timestamp as valid_from,
    '9999-12-31'::timestamp as valid_to,
    true                  as is_current,
    null                  as modified_date

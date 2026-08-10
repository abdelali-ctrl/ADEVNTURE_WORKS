{{ config(
    materialized='table'
) }}

with special_offer as (
    select * from {{ ref('stg_specialoffer') }}
)

select
  
    special_offer_id as sk_special_offer,

    special_offer_id,
    discount_percent,
    discount_type as offer_type,
    discount_category as offer_category,
    start_date,
    end_date,
    min_quantity as min_qty
from special_offer

union all

select
    -1 as sk_special_offer,
    -1 as special_offer_id,
    0 as discount_percent,
    'Unknown' as offer_type,
    'Unknown' as offer_category,
    null as start_date,
    null as end_date,
    null as min_qty
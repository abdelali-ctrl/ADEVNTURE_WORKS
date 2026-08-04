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
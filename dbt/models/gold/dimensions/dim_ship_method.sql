{{ config(
    materialized='table') }}

with ship_method as (
    select * from {{ ref('stg_shipmethod') }}
)

select
    ship_method_id as sk_ship_method,
    ship_method_id,
    ship_method_name,
    ship_base,
    ship_rate,
    modified_date
from ship_method

union all

select
    -1 as sk_ship_method,
    -1 as ship_method_id,
    'Unknown' as ship_method_name,
    0 as ship_base,
    0 as ship_rate,
    null as modified_date
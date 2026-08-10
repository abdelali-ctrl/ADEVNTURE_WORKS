{{ config(materialized='table') }}

/*
    dim_sales_reason (cahier §5.2)
    Type 1. Reached ONLY through bridge_order_sales_reason, never joined to a
    fact directly (an order can have several reasons -> M:N).
*/

with reason as (
    select * from {{ ref('stg_reason') }}
)

select
    sales_reason_id as sk_sales_reason,
    sales_reason_id,
    sales_reason_name,
    reason_type,
    modified_date
from reason

union all

select
    -1 as sk_sales_reason,
    -1 as sales_reason_id,
    'Unknown' as sales_reason_name,
    'Unknown' as reason_type,
    null as modified_date

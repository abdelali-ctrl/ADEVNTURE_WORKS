{{ config(
    materialized='table'
) }}

with source_orders as (
    select distinct
        order_status,
        online_order_flag
    from {{ ref('stg_orderheader') }}
),

order_status_dim as (
    select
        {{ dbt_utils.generate_surrogate_key(['order_status', 'online_order_flag']) }} as sk_order_status,
        
        order_status as status_id,
        
        case order_status
            when 1 then 'In Process'
            when 2 then 'Approved'
            when 3 then 'Backordered'
            when 4 then 'Rejected'
            when 5 then 'Shipped'
            when 6 then 'Cancelled'
            else 'Unknown'
        end as status_name,
        
        case 
            when online_order_flag = 1 then 'Online'
            when online_order_flag = 0 then 'Reseller'
            else 'Unknown'
        end as sales_channel

    from source_orders
)

select
    sk_order_status,
    status_id,
    status_name,
    sales_channel
from order_status_dim

union all

select
    '-1' as sk_order_status,
    -1 as status_id,
    'Unknown' as status_name,
    'Unknown' as sales_channel
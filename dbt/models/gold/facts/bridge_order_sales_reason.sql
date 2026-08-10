{{ config(materialized='table') }}

/*
    bridge_order_sales_reason (cahier §5.1 / §5.3 #4)  --  BRIDGE
    GRAIN: one row per order per sales reason.

    One order can carry several sales reasons. Joining the fact straight to
    dim_sales_reason would multiply revenue by the number of reasons, silently.
    Decision: allocation_factor = 1 / (reasons on that order). Multiply any
    measure by it and revenue-by-reason sums back to the true total.

    Usage:  fct_sales_order_line -> bridge (on sales_order_id)
                                 -> dim_sales_reason (on sk_sales_reason)
            then always  sum(measure * allocation_factor).
    Orders with no recorded reason are not in this bridge (expected).
*/

with order_reasons as (
    select * from {{ ref('stg_orderheadersalesreason') }}
),

reason_counts as (
    select
        sales_order_id,
        count(*) as reason_count
    from order_reasons
    group by 1
)

select
    {{ dbt_utils.generate_surrogate_key(['orr.sales_order_id', 'orr.sales_reason_id']) }} as sk_order_sales_reason,
    orr.sales_order_id,
    coalesce(dsr.sk_sales_reason, -1) as sk_sales_reason,
    rc.reason_count,
    1.0 / rc.reason_count as allocation_factor
from order_reasons orr
left join reason_counts rc on orr.sales_order_id = rc.sales_order_id
left join {{ ref('dim_sales_reason') }} dsr on orr.sales_reason_id = dsr.sales_reason_id

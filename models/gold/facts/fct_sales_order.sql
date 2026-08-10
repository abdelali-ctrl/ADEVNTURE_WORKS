{{
    config(
        materialized='incremental',
        unique_key='sk_sales_order',
        incremental_strategy='merge',
        cluster_by=['sk_order_date']
    )
}}

/*
    fct_sales_order (cahier §5.1)  --  TRANSACTION FACT, header grain
    GRAIN: one row per SALES ORDER.

    CHARGEMENT INCREMENTAL : watermark sur modified_date (lookback 3 jours),
    MERGE sur sk_sales_order -> idempotent.

    Freight, tax and total_due are order-level facts. At line grain they can
    only be allocated, and an allocation is an assumption. This table holds the
    unallocated truth straight from the source, plus a computed_subtotal rolled
    up from the lines so the reconciliation variance is queryable.

    TRAP: do not join this to fct_sales_order_line and sum measures from both --
    that fans out and multiplies header values by the line count.
*/

with order_header as (
    select * from {{ ref('int_orderheader') }}
    {% if is_incremental() %}
    where modified_date >= (
        select dateadd(day, -3, coalesce(max(source_modified_date), '1900-01-01'::date))
        from {{ this }}
    )
    {% endif %}
),

line_rollup as (
    select
        sales_order_id,
        count(*) as line_count,
        sum(order_quantity) as total_qty,
        count(distinct product_id) as distinct_products,
        sum(order_quantity * unit_price * (1 - unit_price_discount)) as computed_subtotal
    from {{ ref('int_orderdetail') }}
    group by 1
)

select
    {{ dbt_utils.generate_surrogate_key(['oh.sales_order_id']) }} as sk_sales_order,

    oh.sales_order_id,
    oh.sales_order_number,
    oh.purchase_order_number,
    oh.account_number,

    coalesce(c.sk_customer, '-1')       as sk_customer,
    coalesce(s.sk_salesperson, -1)      as sk_salesperson,
    coalesce(t.sk_territory, -1)        as sk_territory,
    coalesce(sm.sk_ship_method, -1)     as sk_ship_method,
    coalesce(os.sk_order_status, '-1')  as sk_order_status,
    coalesce(cur.sk_currency, '-1')     as sk_currency,
    coalesce(geo_bill.sk_geography, -1) as sk_bill_to_geography,
    coalesce(geo_ship.sk_geography, -1) as sk_ship_to_geography,

    oh.currency_rate_id,
    (oh.currency_rate_id is not null)   as is_multicurrency_order,

    coalesce(d_order.sk_date, -1)       as sk_order_date,
    coalesce(d_due.sk_date, -1)         as sk_due_date,
    coalesce(d_ship.sk_date, -1)        as sk_ship_date,

    -- Source measures, unallocated
    oh.sub_total as subtotal,
    oh.tax_amount,
    oh.freight_amount as freight,
    oh.total_due,

    -- Rolled up from the lines
    lr.line_count,
    lr.total_qty,
    lr.distinct_products,
    lr.computed_subtotal,
    round(oh.sub_total - lr.computed_subtotal, 2) as subtotal_variance,

    -- Fulfilment lags. NULL ship_date = not yet shipped (correct).
    datediff(day, oh.order_date, oh.ship_date) as days_to_ship,
    datediff(day, oh.order_date, oh.due_date)  as days_promised,
    case
        when oh.ship_date is null then null
        when oh.ship_date <= oh.due_date then true
        else false
    end as is_shipped_on_time,

    oh.online_order_flag,
    oh.revision_number,

    oh.modified_date as source_modified_date,
    current_timestamp() as dwh_loaded_at

from order_header oh
left join line_rollup lr on oh.sales_order_id = lr.sales_order_id

left join {{ ref('dim_customer') }} c
    on oh.customer_id = c.customer_id
    and oh.order_date >= c.valid_from
    and oh.order_date <  c.valid_to
left join {{ ref('dim_currency') }} cur on cur.currency_code = 'USD'
left join {{ ref('dim_salesperson') }} s on oh.sales_person_id = s.salesperson_id
left join {{ ref('dim_territory') }} t on oh.territory_id = t.territory_id
left join {{ ref('dim_ship_method') }} sm on oh.ship_method_id = sm.ship_method_id
left join {{ ref('dim_order_status') }} os
    on {{ dbt_utils.generate_surrogate_key(['oh.order_status', 'oh.online_order_flag']) }} = os.sk_order_status
left join {{ ref('dim_geography') }} geo_bill on oh.bill_to_address_id = geo_bill.address_id
left join {{ ref('dim_geography') }} geo_ship on oh.ship_to_address_id = geo_ship.address_id
left join {{ ref('dim_date') }} d_order on oh.order_date = d_order.date_actual
left join {{ ref('dim_date') }} d_due on oh.due_date = d_due.date_actual
left join {{ ref('dim_date') }} d_ship on oh.ship_date = d_ship.date_actual

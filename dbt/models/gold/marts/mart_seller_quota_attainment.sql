{{ config(materialized='table') }}

/*
    mart_seller_quota_attainment (cahier §2.1 / Semaine 4)
    GRAIN : un vendeur x un trimestre.

    Compare le CA reel realise au quota, par vendeur et par trimestre.
    Les quotas viennent de fct_sales_quota ; le realise est agrege depuis
    fct_sales_order_line sur la meme maille (vendeur + trimestre).
*/

with actuals as (
    select
        l.sk_salesperson,
        d.year_quarter,
        d.year,
        d.quarter,
        sum(l.net_amount)   as actual_revenue,
        sum(l.gross_margin) as actual_margin,
        count(distinct l.sales_order_id) as orders
    from {{ ref('fct_sales_order_line') }} l
    join {{ ref('dim_date') }} d on l.sk_order_date = d.sk_date
    where l.sk_salesperson <> -1
    group by 1, 2, 3, 4
),

quotas as (
    select
        q.sk_salesperson,
        d.year_quarter,
        sum(q.quota_amount) as quota_amount
    from {{ ref('fct_sales_quota') }} q
    join {{ ref('dim_date') }} d on q.sk_quota_date = d.sk_date
    where q.sk_salesperson <> -1
    group by 1, 2
),

combined as (
    select
        coalesce(a.sk_salesperson, qu.sk_salesperson) as sk_salesperson,
        coalesce(a.year_quarter, qu.year_quarter)     as year_quarter,
        a.year,
        a.quarter,
        coalesce(a.actual_revenue, 0)                 as actual_revenue,
        coalesce(a.actual_margin, 0)                  as actual_margin,
        coalesce(a.orders, 0)                         as orders,
        qu.quota_amount
    from actuals a
    full outer join quotas qu
        on a.sk_salesperson = qu.sk_salesperson
        and a.year_quarter = qu.year_quarter
)

select
    c.sk_salesperson,
    sp.salesperson_id,
    sp.salesperson_name,
    c.year_quarter,
    c.year,
    c.quarter,

    c.quota_amount,
    c.actual_revenue,
    c.actual_margin,
    c.orders,

    c.actual_revenue - coalesce(c.quota_amount, 0)          as variance_to_quota,
    c.actual_revenue / nullif(c.quota_amount, 0)            as attainment_pct,
    case
        when c.quota_amount is null then 'Sans quota'
        when c.actual_revenue >= c.quota_amount then 'Atteint'
        else 'Non atteint'
    end                                                     as attainment_status,

    current_timestamp()                                     as dwh_loaded_at

from combined c
left join {{ ref('dim_salesperson') }} sp on c.sk_salesperson = sp.sk_salesperson

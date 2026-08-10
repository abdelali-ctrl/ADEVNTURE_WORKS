{{ config(materialized='table') }}

/*
    mart_customer_clv_rfm (cahier §2.1 / Semaine 4)
    GRAIN : un client.

    Répond à "qui sont nos meilleurs clients", en séparant particuliers et
    revendeurs (dim_customer.customer_type). Fournit :
      - RFM : Récence, Fréquence, Montant + scores 1..5 et segment
      - CLV (proxy) : marge brute cumulée générée par le client
*/

with orders as (
    select
        o.sk_customer,
        o.sales_order_id,
        d.date_actual as order_date,
        o.subtotal,
        o.total_due
    from {{ ref('fct_sales_order') }} o
    join {{ ref('dim_date') }} d on o.sk_order_date = d.sk_date
),

reference as (
    select max(order_date) as as_of_date from orders
),

margin_per_customer as (
    select
        sk_customer,
        sum(net_amount)   as total_revenue,
        sum(gross_margin) as total_margin
    from {{ ref('fct_sales_order_line') }}
    group by 1
),

rfm_base as (
    select
        o.sk_customer,
        datediff(day, max(o.order_date), r.as_of_date) as recency_days,
        count(distinct o.sales_order_id)               as frequency_orders,
        sum(o.total_due)                               as monetary_total,
        min(o.order_date)                              as first_order_date,
        max(o.order_date)                              as last_order_date
    from orders o
    cross join reference r
    group by o.sk_customer, r.as_of_date
),

scored as (
    select
        b.*,
        -- Récence : plus c'est récent, plus le score est haut (ordre inversé).
        6 - ntile(5) over (order by b.recency_days)         as r_score,
        ntile(5) over (order by b.frequency_orders)         as f_score,
        ntile(5) over (order by b.monetary_total)           as m_score
    from rfm_base b
)

select
    s.sk_customer,
    c.customer_id,
    c.customer_type,
    c.customer_display_name,
    c.territory_id,

    s.recency_days,
    s.frequency_orders,
    s.monetary_total,
    s.first_order_date,
    s.last_order_date,

    s.r_score,
    s.f_score,
    s.m_score,
    (s.r_score + s.f_score + s.m_score)             as rfm_score,
    concat(s.r_score, s.f_score, s.m_score)         as rfm_cell,

    case
        when s.r_score >= 4 and s.f_score >= 4 then 'Champions'
        when s.r_score >= 4 and s.f_score >= 2 then 'Loyaux'
        when s.r_score >= 4                    then 'Nouveaux'
        when s.r_score >= 3 and s.f_score >= 3 then 'A risque'
        when s.r_score <= 2 and s.f_score >= 4 then 'A reconquerir'
        else 'Dormants'
    end                                             as rfm_segment,

    coalesce(mpc.total_revenue, 0)                  as lifetime_revenue,
    coalesce(mpc.total_margin, 0)                   as lifetime_margin,   -- proxy CLV

    current_timestamp()                             as dwh_loaded_at

from scored s
left join {{ ref('dim_customer') }} c on s.sk_customer = c.sk_customer
left join margin_per_customer mpc on s.sk_customer = mpc.sk_customer
where s.sk_customer <> '-1'

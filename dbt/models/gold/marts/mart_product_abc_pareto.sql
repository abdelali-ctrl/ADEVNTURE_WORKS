{{ config(materialized='table') }}

/*
    mart_product_abc_pareto (cahier §2.1 / Semaine 4)
    GRAIN : un produit.

    Classification ABC / Pareto par chiffre d'affaires :
      - A : produits cumulant jusqu'a 80% du CA
      - B : de 80% a 95%
      - C : les 5% restants
    Plus marge, taux de marge et rang.
*/

with product_sales as (
    select
        sk_product,
        sum(net_amount)   as revenue,
        sum(gross_margin) as margin,
        sum(order_qty)    as units_sold,
        count(*)          as line_count
    from {{ ref('fct_sales_order_line') }}
    where sk_product <> '-1'
    group by 1
),

ranked as (
    select
        ps.*,
        sum(revenue) over ()                                          as total_revenue,
        row_number() over (order by revenue desc)                     as revenue_rank,
        sum(revenue) over (order by revenue desc
                           rows between unbounded preceding and current row) as running_revenue
    from product_sales ps
),

classified as (
    select
        r.*,
        r.running_revenue / nullif(r.total_revenue, 0) as cumulative_revenue_pct,
        case
            when r.running_revenue / nullif(r.total_revenue, 0) <= 0.80 then 'A'
            when r.running_revenue / nullif(r.total_revenue, 0) <= 0.95 then 'B'
            else 'C'
        end as abc_class
    from ranked r
)

select
    c.sk_product,
    p.product_id,
    p.product_name,
    p.subcategory_name,
    p.category_name,

    c.revenue,
    c.margin,
    c.margin / nullif(c.revenue, 0)     as margin_pct,
    c.units_sold,
    c.line_count,

    c.revenue_rank,
    c.cumulative_revenue_pct,
    c.abc_class,

    current_timestamp()                 as dwh_loaded_at

from classified c
left join {{ ref('dim_product') }} p on c.sk_product = p.sk_product

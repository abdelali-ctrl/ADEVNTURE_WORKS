-- Total revenue in the fact must equal total revenue in the source, to the cent
-- (cahier Week-3 DoD: "zero variance, or the week is not done").
-- Returns a row (fails) if the absolute variance exceeds one cent.

with fact_revenue as (
    select sum(net_amount) as revenue from {{ ref('fct_sales_order_line') }}
),
source_revenue as (
    select sum(order_quantity * unit_price * (1 - unit_price_discount)) as revenue
    from {{ ref('stg_orderdetail') }}
)
select f.revenue as fact_revenue, s.revenue as source_revenue,
       round(f.revenue - s.revenue, 2) as variance
from fact_revenue f
cross join source_revenue s
where abs(f.revenue - s.revenue) > 0.01

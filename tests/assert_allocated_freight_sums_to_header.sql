-- Allocated freight must sum back to the header freight per order, to the cent
-- (proves the allocation redistributes rather than duplicates -- cahier §5.3 #5).
-- Orders with zero net revenue are excluded (share is undefined -> no allocation).

with allocated as (
    select sales_order_id, sum(allocated_freight) as freight_allocated
    from {{ ref('fct_sales_order_line') }}
    group by 1
),
header as (
    select sales_order_id, freight_amount
    from {{ ref('int_orderheader') }}
),
line_totals as (
    select sales_order_id,
           sum(order_quantity * unit_price * (1 - unit_price_discount)) as order_net
    from {{ ref('int_orderdetail') }}
    group by 1
)
select h.sales_order_id, h.freight_amount, a.freight_allocated,
       round(h.freight_amount - a.freight_allocated, 2) as variance
from header h
join allocated a on h.sales_order_id = a.sales_order_id
join line_totals lt on h.sales_order_id = lt.sales_order_id
where lt.order_net > 0
  and abs(h.freight_amount - a.freight_allocated) > 0.01

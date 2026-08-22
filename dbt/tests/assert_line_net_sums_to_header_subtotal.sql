-- SUM(line net) per order must equal the header SubTotal, to the cent
-- (cahier §5.3 #8). Returns one row per offending order (fails if any).

with line_net as (
    select sales_order_id, sum(net_amount) as lines_net
    from {{ ref('fct_sales_order_line') }}
    group by 1
),
header as (
    select sales_order_id, sub_total
    from {{ ref('int_orderheader') }}
)
select h.sales_order_id, h.sub_total, l.lines_net,
       round(h.sub_total - l.lines_net, 2) as variance
from header h
join line_net l on h.sales_order_id = l.sales_order_id
where abs(h.sub_total - l.lines_net) > 0.01

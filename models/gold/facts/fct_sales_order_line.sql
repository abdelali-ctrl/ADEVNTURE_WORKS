
{{ config(materialized='table') }}

with order_detail as (
    select * from {{ ref('int_orderdetail') }}
),

order_header as (
    select * from {{ ref('int_orderheader') }}
),

product as (
    select * from {{ ref('dim_product') }}
),

customer as (
    select * from {{ ref('dim_customer') }}
),

salesperson as (
    select * from {{ ref('dim_salesperson') }}
),

territory as (
    select * from {{ ref('dim_territory') }}
),

special_offer as (
    select * from {{ ref('dim_special_offer') }}
),

ship_method as (
    select * from {{ ref('dim_ship_method') }}
),

order_status as (
    select * from {{ ref('dim_order_status') }}
),

geography as (
    select * from {{ ref('dim_geography') }}
),

date_dim as (
    select * from {{ ref('dim_date') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['od.sales_order_id', 'od.sales_order_detail_id']) }} as sk_sales_order_line,
    od.sales_order_detail_id,
    oh.sales_order_number,
    p.sk_product,
    c.sk_customer,
    coalesce(s.sk_salesperson, -1) as sk_salesperson,
    t.sk_territory,
    so.sk_special_offer,
    sm.sk_ship_method,
    os.sk_order_status,
    geo_bill.sk_geography as sk_bill_to_geography,
    geo_ship.sk_geography as sk_ship_to_geography,
    d_order.sk_date as sk_order_date,
    d_due.sk_date as sk_due_date,
    d_ship.sk_date as sk_ship_date,
    od.order_quantity as order_qty,
    (od.order_quantity * od.unit_price) * (1 - od.unit_price_discount) as net_amount,
    ((od.order_quantity * od.unit_price) * (1 - od.unit_price_discount)) - (od.order_quantity * p.standard_cost) as gross_margin,
    p.standard_cost as unit_standard_cost,
    oh.freight_amount as allocated_freight,
    oh.tax_amount as allocated_tax
from order_detail od
join order_header oh on od.sales_order_id = oh.sales_order_id
left join product p on od.product_id = p.product_id
left join customer c on oh.customer_id = c.customer_id
left join salesperson s on oh.sales_person_id = s.salesperson_id
left join territory t on oh.territory_id = t.territory_id
left join special_offer so on od.special_offer_id = so.special_offer_id
left join ship_method sm on oh.ship_method_id = sm.ship_method_id
left join order_status os on oh.order_status = os.status_id
left join geography geo_bill on oh.bill_to_address_id = geo_bill.address_id
left join geography geo_ship on oh.ship_to_address_id = geo_ship.address_id
left join date_dim d_order on oh.order_date = d_order.date_actual
left join date_dim d_due on oh.due_date = d_due.date_actual
left join date_dim d_ship on oh.ship_date = d_ship.date_actual
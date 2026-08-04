

{{ config(
    materialized='table') 
}}

with source as (
    select * from {{ source('sales', 'SALESORDERDETAIL') }}
),

cleaned as (
    select
        cast(salesorderid as int) as sales_order_id,
        cast(salesorderdetailid as int) as sales_order_detail_id,
        nullif(trim(carriertrackingnumber), '') as carrier_tracking_number,
        cast(orderqty as int) as order_quantity,
        cast(productid as int) as product_id,
        cast(specialofferid as int) as special_offer_id,
        cast(linetotal as number(19,2)) as line_total, 
        cast(unitprice as number(19,2)) as unit_price,
        cast(unitpricediscount as number(19,2)) as unit_price_discount,
        cast(modifieddate as date) as modified_date,
        cast(rowguid as varchar) as row_guid,   
    from source
)

select * from cleaned




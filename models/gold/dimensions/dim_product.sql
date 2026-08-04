{{ config(
    materialized='table'
) }}

with product as (
    select * from {{ ref('stg_product') }}
),

subcategory as (
    select * from {{ ref('stg_productsubcat') }}
),

category as (
    select * from {{ ref('stg_productcategory') }}
)

select
    p.product_id as sk_product,
    p.product_id,             
    p.product_name,
    p.product_number,
    p.standard_cost,
    p.list_price,
    sc.product_subcategory_name as subcategory_name,
    c.product_category_name as category_name,
    p.modified_date
from product p
left join subcategory sc on p.product_subcategory_id = sc.product_subcategory_id
left join category c on sc.product_category_id = c.product_category_id
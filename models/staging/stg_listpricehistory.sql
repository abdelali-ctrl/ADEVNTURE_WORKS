{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('production','PRODUCTLISTPRICEHISTORY') }}
),

cleaned as (
    select
        cast(productid as int) as product_id,
        cast(startdate as date) as start_date,
        cast(enddate as date) as end_date,
        cast(listprice as int) as list_price, 
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
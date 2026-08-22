{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('sales', 'SPECIALOFFERPRODUCT') }}
),

cleaned as (
    select
        cast(specialofferid as int) as special_offer_id,
        cast(productid as int) as product_id,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
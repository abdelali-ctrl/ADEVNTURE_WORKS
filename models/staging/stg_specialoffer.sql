{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('sales', 'SpecialOffer') }}
),

cleaned as (
    select
        cast(specialofferid as int) as special_offer_id,
        nullif(trim(description), '') as description,
        cast(discountpct as number(19,2)) as discount_percent,
        nullif(trim(type), '') as discount_type,
        nullif(trim(category), '') as discount_category,
        cast(startdate as date) as start_date,
        cast(enddate as date) as end_date,
        cast(minqty as int) as min_quantity,
        cast(maxqty as int) as max_quantity,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
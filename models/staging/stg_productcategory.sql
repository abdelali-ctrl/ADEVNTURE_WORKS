{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('production','productcategory') }}
),

cleaned as (
    select
        cast(productcategoryid as int) as product_category_id,
        nullif(trim(name), '') as product_category_name,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
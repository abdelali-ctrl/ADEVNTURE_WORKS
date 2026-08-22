{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('production','productmodel') }}
),

cleaned as (
    select
        cast(productmodelid as int) as product_model_id,
        nullif(trim(name), '') as product_model_name,
        nullif(trim(catalogdescription), '') as catalog_description,
        nullif(trim(instructions), '') as instructions,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
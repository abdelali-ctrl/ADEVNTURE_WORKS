{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('person','COUNTRYREGION') }}
),

cleaned as (
    select
        nullif(trim(countryregioncode), '') as country_region_code,
        nullif(trim(name), '') as country_region_name,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
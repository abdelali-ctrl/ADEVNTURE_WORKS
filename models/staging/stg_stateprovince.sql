{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('person','STATEPROVINCE') }}
),

cleaned as (
    select
        cast(stateprovinceid as int) as state_province_id,
        nullif(trim(stateprovincecode), '') as state_province_code,
        nullif(trim(countryregioncode), '') as country_region_code,
        cast(isonlystateprovinceflag as int) as is_only_state_province_flag,
        nullif(trim(name), '') as state_province_name,
        cast(territoryid as int) as territory_id,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
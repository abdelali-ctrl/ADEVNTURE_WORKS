{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('sales', 'SALESTERRITORY') }}
),

cleaned as (
    select
        cast(territoryid as int) as territory_id,
        nullif(trim(name), '') as territory_name,
        nullif(trim(countryregioncode), '') as country_region_code,
        nullif(trim("GROUP"), '') as territory_group, 
        cast(salesytd as int) as sales_ytd,
        cast(saleslastyear as int) as sales_last_year,
        cast(costytd as int) as cost_ytd,
        cast(costlastyear as int) as cost_last_year,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
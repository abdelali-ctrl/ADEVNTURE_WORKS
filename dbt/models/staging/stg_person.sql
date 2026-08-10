{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('sales', 'SALESPERSON') }}
),

cleaned as (
    select
        cast(businessentityid as int) as business_entity_id,
        cast(territoryid as int) as territory_id,
        cast(salesquota as number(19,2)) as sales_quota,
        cast(bonus as number(19,2)) as bonus,
        cast(commissionpct as number(19,2)) as commission_percent,
        cast(salesytd as number(19,2)) as sales_ytd,
        cast(saleslastyear as number(19,2)) as sales_last_year,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
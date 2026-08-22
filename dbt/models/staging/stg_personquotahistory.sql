{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('sales', 'SALESPERSONQUOTAHISTORY') }}
),

cleaned as (
    select
        cast(businessentityid as int) as business_entity_id,
        cast(quotadate as date) as quota_date,
        cast(salesquota as number(19,2)) as sales_quota,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('sales', 'STORE') }}
),

cleaned as (
    select
        cast(businessentityid as int) as business_entity_id,
        nullif(trim(name), '') as store_name,
        cast(salespersonid as int) as sales_person_id,
        nullif(trim(demographics), '') as demographics, 
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
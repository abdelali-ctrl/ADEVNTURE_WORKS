{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('person','BUSINESSENTITYADDRESS') }}
),

cleaned as (
    select
        cast(businessentityid as int) as business_entity_id,
        cast(addressid as int) as address_id,
        cast(addresstypeid as int) as address_type_id,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
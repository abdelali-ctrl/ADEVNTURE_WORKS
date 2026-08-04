{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('person','address') }}
),

cleaned as (
    select
        cast(addressid as int) as address_id,
        nullif(trim(addressline1), '') as address_line1,
        nullif(trim(addressline2), '') as address_line2,
        nullif(trim(city), '') as city,
        cast(stateprovinceid as int) as state_province_id,
        nullif(trim(postalcode), '') as postal_code,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
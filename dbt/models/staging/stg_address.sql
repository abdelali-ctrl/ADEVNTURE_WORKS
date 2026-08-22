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
    -- The bronze ADDRESS table was double-loaded (non-idempotent Week-1 load):
    -- 39,228 rows for 19,614 distinct address_ids. Dedupe defensively here so
    -- dim_geography stays 1:1 and the fact does not fan out. The real fix is an
    -- idempotent bronze load; this keeps silver trustworthy until that lands.
    qualify row_number() over (partition by addressid order by modifieddate desc) = 1
)

select * from cleaned
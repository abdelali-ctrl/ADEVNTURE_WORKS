{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('purchasing','shipmethod') }}
),

cleaned as (
    select
        cast(shipmethodid as int) as ship_method_id,
        nullif(trim(name), '') as ship_method_name,
        cast(shipbase as int) as ship_base,       
        cast(shiprate as int) as ship_rate,       
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
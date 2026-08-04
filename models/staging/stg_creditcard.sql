{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('sales', 'CURRENCY') }}
),

cleaned as (
    select
        nullif(trim(currencycode), '') as currency_code,
        nullif(trim(name), '') as currency_name,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
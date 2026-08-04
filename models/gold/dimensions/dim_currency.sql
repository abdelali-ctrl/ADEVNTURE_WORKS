{{ config(
    materialized='table'
) }}

with currency as (
    select * from {{ ref('stg_currency') }}
)

select

    currency_code as sk_currency,
    currency_code,
    currency_name,
    modified_date
   
   from currency
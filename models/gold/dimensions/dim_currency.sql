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

union all

select
    '-1' as sk_currency,
    '-1' as currency_code,
    'Unknown' as currency_name,
    null as modified_date
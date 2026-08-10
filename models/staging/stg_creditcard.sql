{{ config(
    materialized='table'
) }}

-- NOTE: the previous version of this model selected from source('sales','CURRENCY')
-- by copy-paste and returned currency columns, so every credit_card test errored
-- with "invalid identifier". Fixed to read the CREDITCARD source.

with source as (
    select * from {{ source('sales', 'CREDITCARD') }}
),

cleaned as (
    select
        cast(creditcardid as int) as credit_card_id,
        nullif(trim(cardtype), '') as card_type,
        nullif(trim(cardnumber), '') as card_number,
        cast(expmonth as int) as exp_month,
        cast(expyear as int) as exp_year,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned

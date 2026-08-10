{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('sales', 'SALESREASON') }}
),

cleaned as (
    select
        cast(salesreasonid as int) as sales_reason_id,
        nullif(trim(name), '') as sales_reason_name,
        nullif(trim(reasontype), '') as reason_type,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
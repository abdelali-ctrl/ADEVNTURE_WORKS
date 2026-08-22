{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('sales', 'CUSTOMER') }}
),

cleaned as (
    select
        cast(customerid as int) as customer_id,
        cast(personid as int) as person_id,         
        cast(storeid as int) as store_id,           
        cast(territoryid as int) as territory_id,   
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
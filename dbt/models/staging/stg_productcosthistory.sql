{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('production','productcosthistory') }}
),

cleaned as (
    select
        cast(productid as int) as product_id,
        cast(startdate as date) as start_date,
        cast(enddate as date) as end_date,
        cast(standardcost as int) as standard_cost, 
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
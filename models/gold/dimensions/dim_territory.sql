{{ config(
    materialized='table') }}

with territory as (
    select * from {{ ref('stg_territory') }}
)

select
    territory_id as sk_territory,
    territory_id,
    territory_name,
    country_region_code,
    territory_group,
    modified_date
from territory
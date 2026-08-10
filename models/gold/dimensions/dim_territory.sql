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

union all

select
    -1 as sk_territory,
    -1 as territory_id,
    'Unknown' as territory_name,
    'Unknown' as country_region_code,
    'Unknown' as territory_group,
    null as modified_date
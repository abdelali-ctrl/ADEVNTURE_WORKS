{{ config(
    materialized='table') }}

with address as (
    select * from {{ ref('stg_address') }}
),

state_province as (
    select * from {{ ref('stg_stateprovince') }}
),

country_region as (
    select * from {{ ref('stg_contryregion') }}
)

select
   
    a.address_id as sk_geography,
    a.address_id,
    a.address_line1,
    a.address_line2,
    a.city,
    a.postal_code,
    sp.state_province_code,
    sp.state_province_name as state_name,
    cr.country_region_code,
    cr.country_region_name as country_name,
    a.modified_date
from address a
left join state_province sp on a.state_province_id = sp.state_province_id
left join country_region cr on sp.country_region_code = cr.country_region_code
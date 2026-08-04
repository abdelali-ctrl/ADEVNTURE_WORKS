{{ config(
    materialized='table'
) }}

with employe as (
    select * from {{ ref('stg_employe') }}
),

sales_info as (
    select * from {{ ref('stg_person') }}
),

person_name as (
    select * from {{ ref('stg_personne') }}
)

select

    e.business_entity_id as sk_salesperson,
    
    
    e.business_entity_id as salesperson_id,
    trim(concat(coalesce(pn.first_name, ''), ' ', coalesce(pn.last_name, ''))) as salesperson_name,
    e.job_title,
    e.gender,
    e.marital_status,
    e.hire_date,
    
   
    si.sales_quota,
    si.bonus,
    si.commission_percent,
    
   
    e.modified_date
from employe e
left join person_name pn on e.business_entity_id = pn.business_entity_id
left join sales_info si on e.business_entity_id = si.business_entity_id
where e.job_title like '%Sales%'
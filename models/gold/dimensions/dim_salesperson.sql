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

union all

-- Unknown member (§5.3 #2): ~2/3 of orders are online with NO salesperson.
-- Facts point here instead of being silently deleted by an inner join.
select
    -1 as sk_salesperson,
    -1 as salesperson_id,
    'Unknown / Online' as salesperson_name,
    'Unknown' as job_title,
    null as gender,
    null as marital_status,
    null as hire_date,
    null as sales_quota,
    null as bonus,
    null as commission_percent,
    null as modified_date
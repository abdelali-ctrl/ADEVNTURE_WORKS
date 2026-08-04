{{ config(
    materialized='table'
) }}

with customer as (
    select * from {{ ref('stg_customer') }}
),
person_name as (
    select * from {{ ref('stg_personne') }}
),

store as (
    select * from {{ ref('stg_store') }}
)

select
    c.customer_id as sk_customer,
    
    c.customer_id,
    c.person_id,
    c.store_id,
    c.territory_id,
    
    
    trim(concat(coalesce(pn.first_name, ''), ' ', coalesce(pn.last_name, ''))) as customer_name,
    
    s.store_name as store_name,
    
    c.modified_date
from customer c
left join person_name pn on c.person_id = pn.business_entity_id
left join store s on c.store_id = s.business_entity_id
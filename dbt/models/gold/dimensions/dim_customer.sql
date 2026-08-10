{{ config(materialized='table') }}

/*
    dim_customer — SCD Type 2 (cahier §5.2 / §5.3 #3).
    Alimentee par `snap_customer`. Conforme les deux types de clients
    (particulier via Person, revendeur via Store) dans une seule dimension, avec
    historisation valid_from / valid_to / is_current. Le fait joint en
    point-in-time sur la date de commande.
*/

with versions as (
    select
        *,
        min(dbt_valid_from) over (partition by customer_id) as first_valid_from
    from {{ ref('snap_customer') }}
),

person_name as (select * from {{ ref('stg_personne') }}),
store as (select * from {{ ref('stg_store') }})

select
    {{ dbt_utils.generate_surrogate_key(['v.customer_id', 'v.dbt_valid_from']) }} as sk_customer,
    v.customer_id,
    v.person_id,
    v.store_id,
    v.territory_id,

    case
        when v.store_id is not null then 'Reseller'
        when v.person_id is not null then 'Individual'
        else 'Unknown'
    end as customer_type,

    trim(concat(coalesce(pn.first_name, ''), ' ', coalesce(pn.last_name, ''))) as customer_name,
    s.store_name,
    coalesce(
        nullif(s.store_name, ''),
        nullif(trim(concat(coalesce(pn.first_name, ''), ' ', coalesce(pn.last_name, ''))), ''),
        'Unknown'
    ) as customer_display_name,

    case when v.dbt_valid_from = v.first_valid_from
         then '1900-01-01'::timestamp
         else v.dbt_valid_from end          as valid_from,
    coalesce(v.dbt_valid_to, '9999-12-31'::timestamp) as valid_to,
    (v.dbt_valid_to is null)                as is_current,
    v.modified_date
from versions v
left join person_name pn on v.person_id = pn.business_entity_id
left join store s on v.store_id = s.business_entity_id

union all

-- Membre inconnu (§5.4)
select
    '-1'                    as sk_customer,
    -1                     as customer_id,
    null                  as person_id,
    null                  as store_id,
    null                  as territory_id,
    'Unknown'             as customer_type,
    'Unknown'             as customer_name,
    'Unknown'             as store_name,
    'Unknown'             as customer_display_name,
    '1900-01-01'::timestamp as valid_from,
    '9999-12-31'::timestamp as valid_to,
    true                  as is_current,
    null                  as modified_date

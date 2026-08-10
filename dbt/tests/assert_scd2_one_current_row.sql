-- SCD2 : exactement une ligne courante (is_current) par cle metier, dans chaque
-- dimension historisee (cahier DoD Semaine 2). Retourne une ligne (echec) si une
-- cle a 0 ou >1 version courante. Le membre inconnu (-1) est exclu.

with current_counts as (
    select 'dim_product' as dim, product_id as nk, count_if(is_current) as n_current
    from {{ ref('dim_product') }}
    where product_id <> -1
    group by 1, 2

    union all

    select 'dim_customer' as dim, customer_id as nk, count_if(is_current) as n_current
    from {{ ref('dim_customer') }}
    where customer_id <> -1
    group by 1, 2
)
select *
from current_counts
where n_current <> 1

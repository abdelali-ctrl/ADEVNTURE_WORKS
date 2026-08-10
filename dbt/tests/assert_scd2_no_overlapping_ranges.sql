-- SCD2 : aucune paire de versions d'une meme cle ne doit avoir des plages de
-- validite qui se chevauchent (cahier DoD Semaine 2). Retourne une ligne (echec)
-- par chevauchement detecte.

with product_overlaps as (
    select a.product_id
    from {{ ref('dim_product') }} a
    join {{ ref('dim_product') }} b
        on a.product_id = b.product_id
        and a.sk_product <> b.sk_product
        and a.valid_from < b.valid_to
        and b.valid_from < a.valid_to
    where a.product_id <> -1
),

customer_overlaps as (
    select a.customer_id
    from {{ ref('dim_customer') }} a
    join {{ ref('dim_customer') }} b
        on a.customer_id = b.customer_id
        and a.sk_customer <> b.sk_customer
        and a.valid_from < b.valid_to
        and b.valid_from < a.valid_to
    where a.customer_id <> -1
)

select 'dim_product' as dim, product_id as nk from product_overlaps
union all
select 'dim_customer' as dim, customer_id as nk from customer_overlaps

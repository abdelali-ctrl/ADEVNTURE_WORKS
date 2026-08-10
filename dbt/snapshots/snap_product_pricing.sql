{% snapshot snap_product_pricing %}
{{
    config(
        target_schema='silver',
        unique_key='product_id',
        strategy='check',
        check_cols=['standard_cost', 'list_price']
    )
}}

/*
    SCD2 sur le prix/cout courant du produit (cahier §5.2 : "price/cost history").
    Complementaire des tables d'historique source : capture les evolutions du
    cout standard et du prix catalogue *courants* au fil des executions dbt, meme
    lorsque la source ne fournit pas de plage de validite.
    Pour le point-in-time historique, voir int_product_cost_scd / int_product_price_scd.
*/

select
    product_id,
    standard_cost,
    list_price,
    modified_date
from {{ ref('stg_product') }}

{% endsnapshot %}

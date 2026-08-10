{% snapshot snap_product %}
{{
    config(
        target_schema='silver',
        unique_key='product_id',
        strategy='check',
        check_cols=['product_name', 'standard_cost', 'list_price',
                    'subcategory_id', 'product_number']
    )
}}

/*
    SCD2 sur le produit (cahier §5.2).
    Strategie 'check' : une nouvelle version est creee des qu'une colonne suivie
    change (nom, cout standard, prix catalogue, sous-categorie). dbt maintient
    dbt_valid_from / dbt_valid_to / dbt_scd_id automatiquement.

    A chaque `dbt snapshot`, l'etat courant est capture. La 1ere execution pose
    la version initiale ; les suivantes historisent les changements.
*/

select
    product_id,
    product_name,
    product_number,
    standard_cost,
    list_price,
    product_subcategory_id as subcategory_id,
    modified_date
from {{ ref('stg_product') }}

{% endsnapshot %}

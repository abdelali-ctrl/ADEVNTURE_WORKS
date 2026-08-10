{% snapshot snap_customer %}
{{
    config(
        target_schema='silver',
        unique_key='customer_id',
        strategy='check',
        check_cols=['person_id', 'store_id', 'territory_id']
    )
}}

/*
    SCD2 sur le client (cahier §5.2 / §5.3 #3).
    Historise les changements structurants d'un client : rattachement
    personne/magasin et territoire. Permet de savoir a quel territoire un client
    etait rattache au moment d'une commande.
*/

select
    customer_id,
    person_id,
    store_id,
    territory_id,
    modified_date
from {{ ref('stg_customer') }}

{% endsnapshot %}

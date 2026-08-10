{{ config(materialized='table') }}

/*
    fct_sales_quota (cahier §5.1)  --  TRANSACTION FACT
    GRAIN: one row per salesperson per quota period.

    Feeds the "revenue vs. quota by salesperson and quarter" question (§2.1).
    Compare against revenue by aggregating fct_sales_order_line to the same
    salesperson + quarter grain.
*/

with quota as (
    select * from {{ ref('stg_personquotahistory') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['q.business_entity_id', 'q.quota_date']) }} as sk_sales_quota,

    coalesce(s.sk_salesperson, -1)  as sk_salesperson,
    coalesce(d.sk_date, -1)         as sk_quota_date,

    q.business_entity_id as salesperson_id,
    q.quota_date,
    q.sales_quota as quota_amount

from quota q
left join {{ ref('dim_salesperson') }} s on q.business_entity_id = s.salesperson_id
left join {{ ref('dim_date') }} d on q.quota_date = d.date_actual

{{
    config(
        materialized='incremental',
        unique_key='sk_sales_order_line',
        incremental_strategy='merge',
        cluster_by=['sk_order_date']
    )
}}

/*
    fct_sales_order_line (cahier §5.1)  --  TRANSACTION FACT, centre of the star
    GRAIN: one row per LINE ITEM of one sales order (sales_order_detail_id).

    CHARGEMENT INCREMENTAL (cahier Semaine 3) :
      Watermark sur modified_date avec un rattrapage de 3 jours (lookback) pour
      recuperer les lignes arrivees en retard. MERGE sur sk_sales_order_line rend
      le chargement idempotent (rejouer 2x ne change aucune ligne).

    Key fixes over the first version:
      1. Cost is point-in-time (int_product_cost_scd), joined on order_date
         between valid_from/valid_to -- NOT dim_product's current cost (§5.3 #1).
      2. Freight & tax are ALLOCATED pro-rata by each line's share of order net
         revenue -- not the full header value copied onto every line (§5.3 #5).
         The unallocated truth lives in fct_sales_order.
      3. Every FK left-joins and coalesces to the unknown member (-1), so no
         fact row is ever lost -- especially the ~2/3 online orders with no
         salesperson (§5.3 #2 / §5.4).
      4. dim_order_status is joined on its full (status, online_flag) surrogate
         key, not on status alone, which previously fanned out the grain.

    RECONCILIATION CONTRACT (enforced by tests):
      * count(*) = source order-line count.
      * sum(net_amount) per order = header sub_total, to the cent.
      * sum(allocated_freight) per order = header freight, to the cent.
*/

with order_detail as (
    select * from {{ ref('int_orderdetail') }}
    {% if is_incremental() %}
    where modified_date >= (
        select dateadd(day, -3, coalesce(max(source_modified_date), '1900-01-01'::date))
        from {{ this }}
    )
    {% endif %}
),

order_header as (
    select * from {{ ref('int_orderheader') }}
),

-- Line shares are computed from the LINE data so they always sum to 1.
order_line_totals as (
    select
        sales_order_id,
        sum(order_quantity * unit_price * (1 - unit_price_discount)) as order_net_total,
        count(*) as order_line_count
    from {{ ref('int_orderdetail') }}
    group by 1
)

select
    {{ dbt_utils.generate_surrogate_key(['od.sales_order_id', 'od.sales_order_detail_id']) }} as sk_sales_order_line,

    -- Degenerate dimensions (§5.2): identify the transaction, no dim of their own.
    od.sales_order_id,
    od.sales_order_detail_id,
    oh.sales_order_number,

    -- Foreign keys -- coalesced to the unknown member so joins never drop rows.
    -- dim_product / dim_customer sont SCD2 -> cle version-level (hash), inconnu '-1'.
    coalesce(p.sk_product, '-1')        as sk_product,
    coalesce(c.sk_customer, '-1')       as sk_customer,
    coalesce(s.sk_salesperson, -1)      as sk_salesperson,
    coalesce(t.sk_territory, -1)        as sk_territory,
    coalesce(so.sk_special_offer, -1)   as sk_special_offer,
    coalesce(sm.sk_ship_method, -1)     as sk_ship_method,
    coalesce(os.sk_order_status, '-1')  as sk_order_status,
    coalesce(cur.sk_currency, '-1')     as sk_currency,
    coalesce(geo_bill.sk_geography, -1) as sk_bill_to_geography,
    coalesce(geo_ship.sk_geography, -1) as sk_ship_to_geography,

    -- Multi-devises (§5.3 #7 / ADR-0009) : reporting en USD. Les commandes avec un
    -- currency_rate_id ont ete passees dans une autre devise ; la reconstitution du
    -- montant d'origine attend le chargement de CurrencyRate (non charge en bronze).
    oh.currency_rate_id,
    (oh.currency_rate_id is not null)   as is_multicurrency_order,

    -- Role-playing date keys (§5.2): three roles, one dim_date.
    coalesce(d_order.sk_date, -1)       as sk_order_date,
    coalesce(d_due.sk_date, -1)         as sk_due_date,
    coalesce(d_ship.sk_date, -1)        as sk_ship_date,

    -- Measures: quantity and revenue
    od.order_quantity as order_qty,
    od.unit_price,
    od.unit_price_discount as discount_pct,
    (od.order_quantity * od.unit_price) as gross_amount,
    (od.order_quantity * od.unit_price * od.unit_price_discount) as discount_amount,
    (od.order_quantity * od.unit_price * (1 - od.unit_price_discount)) as net_amount,

    -- Measures: point-in-time cost and margin (§5.3 #1)
    coalesce(pc.standard_cost, p.standard_cost, 0) as unit_standard_cost,
    coalesce(pc.standard_cost, p.standard_cost, 0) * od.order_quantity as total_cost,
    coalesce(pc.is_fallback_cost, true) as is_fallback_cost,
    (od.order_quantity * od.unit_price * (1 - od.unit_price_discount))
        - (coalesce(pc.standard_cost, p.standard_cost, 0) * od.order_quantity) as gross_margin,

    -- List price that applied on the order date, and the true effective discount.
    pp.list_price as list_price_at_order_date,
    case
        when pp.list_price > 0 then 1 - (od.unit_price / pp.list_price)
        else 0
    end as effective_discount_pct,

    -- Measures: allocated from the header, pro-rata by line net share (§5.3 #5)
    oh.freight_amount
        * ((od.order_quantity * od.unit_price * (1 - od.unit_price_discount))
           / nullif(olt.order_net_total, 0)) as allocated_freight,
    oh.tax_amount
        * ((od.order_quantity * od.unit_price * (1 - od.unit_price_discount))
           / nullif(olt.order_net_total, 0)) as allocated_tax,
    (od.order_quantity * od.unit_price * (1 - od.unit_price_discount))
        / nullif(olt.order_net_total, 0) as line_share_of_order,

    -- Audit / watermark incremental
    od.modified_date as source_modified_date,
    current_timestamp() as dwh_loaded_at

from order_detail od
inner join order_header oh on od.sales_order_id = oh.sales_order_id
left join order_line_totals olt on od.sales_order_id = olt.sales_order_id

-- SCD2 : selectionner la version en vigueur A LA DATE DE COMMANDE
left join {{ ref('dim_product') }} p
    on od.product_id = p.product_id
    and oh.order_date >= p.valid_from
    and oh.order_date <  p.valid_to
left join {{ ref('dim_customer') }} c
    on oh.customer_id = c.customer_id
    and oh.order_date >= c.valid_from
    and oh.order_date <  c.valid_to
left join {{ ref('dim_salesperson') }} s on oh.sales_person_id = s.salesperson_id
-- Devise de reporting = USD (§5.3 #7)
left join {{ ref('dim_currency') }} cur on cur.currency_code = 'USD'
left join {{ ref('dim_territory') }} t on oh.territory_id = t.territory_id
left join {{ ref('dim_special_offer') }} so on od.special_offer_id = so.special_offer_id
left join {{ ref('dim_ship_method') }} sm on oh.ship_method_id = sm.ship_method_id

-- Junk dim: join on the FULL surrogate key, not status alone (avoids fan-out).
left join {{ ref('dim_order_status') }} os
    on {{ dbt_utils.generate_surrogate_key(['oh.order_status', 'oh.online_order_flag']) }} = os.sk_order_status

left join {{ ref('dim_geography') }} geo_bill on oh.bill_to_address_id = geo_bill.address_id
left join {{ ref('dim_geography') }} geo_ship on oh.ship_to_address_id = geo_ship.address_id

-- Point-in-time cost and price (date-ranged joins)
left join {{ ref('int_product_cost_scd') }} pc
    on od.product_id = pc.product_id
    and oh.order_date >= pc.valid_from
    and oh.order_date <  pc.valid_to
left join {{ ref('int_product_price_scd') }} pp
    on od.product_id = pp.product_id
    and oh.order_date >= pp.valid_from
    and oh.order_date <  pp.valid_to

-- Role-playing date joins
left join {{ ref('dim_date') }} d_order on oh.order_date = d_order.date_actual
left join {{ ref('dim_date') }} d_due on oh.due_date = d_due.date_actual
left join {{ ref('dim_date') }} d_ship on oh.ship_date = d_ship.date_actual

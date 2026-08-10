{{ config(materialized='table') }}

/*
    int_product_price_scd
    Grain: one row per product per list-price validity period.

    Same point-in-time pattern as int_product_cost_scd, applied to
    ProductListPriceHistory. Lets the fact recover the list price that applied
    on the order date, so the *effective* discount (list vs. actual unit price)
    can be measured rather than assumed.
*/

with price_history as (

    select
        product_id,
        list_price,
        start_date                                          as valid_from,
        coalesce(end_date, '9999-12-31'::date)              as valid_to,
        false                                               as is_fallback_price
    from {{ ref('stg_listpricehistory') }}

),

products_without_history as (

    select
        p.product_id,
        p.list_price,
        '1900-01-01'::date      as valid_from,
        '9999-12-31'::date      as valid_to,
        true                    as is_fallback_price
    from {{ ref('stg_product') }} p
    left join price_history ph on p.product_id = ph.product_id
    where ph.product_id is null

)

select * from price_history
union all
select * from products_without_history

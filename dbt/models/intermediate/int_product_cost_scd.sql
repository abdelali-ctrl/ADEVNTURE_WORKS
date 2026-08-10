{{ config(materialized='table') }}

/*
    int_product_cost_scd
    Grain: one row per product per cost validity period.

    THE POINT-IN-TIME PROBLEM (cahier §5.3 #1)
    Product.StandardCost is TODAY'S cost. Costing a 2012 order with today's
    cost silently distorts every historical margin. ProductCostHistory holds
    the real answer: cost with validity ranges. This model closes the ranges
    so a fact can join on  order_date between valid_from and valid_to.

    Two fixes:
      1. The open current row has end_date = NULL -> closed to 9999-12-31 so
         BETWEEN works without special casing.
      2. Products with no cost history would get no match and an inner join
         would delete their fact rows. A synthetic fallback row covering all
         time is emitted from the current standard cost, flagged
         is_fallback_cost so the compromise is visible in the data.
*/

with cost_history as (

    select
        product_id,
        standard_cost,
        start_date                                          as valid_from,
        coalesce(end_date, '9999-12-31'::date)              as valid_to,
        false                                               as is_fallback_cost
    from {{ ref('stg_productcosthistory') }}

),

products_without_history as (

    select
        p.product_id,
        p.standard_cost,
        '1900-01-01'::date      as valid_from,
        '9999-12-31'::date      as valid_to,
        true                    as is_fallback_cost
    from {{ ref('stg_product') }} p
    left join cost_history ch on p.product_id = ch.product_id
    where ch.product_id is null

)

select * from cost_history
union all
select * from products_without_history

-- The point-in-time cost must actually differ from the naive current-cost
-- version (cahier Week-3 DoD: "a query showing how much it differs").
-- This test FAILS (returns zero rows) if the point-in-time join is doing
-- nothing -- i.e. it asserts that at least some lines are costed differently
-- from dim_product's current standard cost.

with compare as (
    select
        f.sk_sales_order_line,
        f.unit_standard_cost as pit_cost,
        p.standard_cost      as current_cost
    from {{ ref('fct_sales_order_line') }} f
    join {{ ref('dim_product') }} p on f.sk_product = p.sk_product
    where f.is_fallback_cost = false
),
diff_count as (
    select count(*) as differing_rows
    from compare
    where abs(pit_cost - current_cost) > 0.001
)
-- Fail (return a row) only if NOTHING differs, which would mean the
-- point-in-time join was not applied.
select differing_rows
from diff_count
where differing_rows = 0

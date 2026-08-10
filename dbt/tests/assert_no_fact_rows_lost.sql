-- No fact row may be lost to a join (cahier Week-3 DoD).
-- Passes when the line fact has exactly as many rows as source order lines.
-- Returns a row (fails) if the counts differ.

with fact_count as (
    select count(*) as n from {{ ref('fct_sales_order_line') }}
),
source_count as (
    select count(*) as n from {{ ref('stg_orderdetail') }}
)
select f.n as fact_rows, s.n as source_rows
from fact_count f
cross join source_count s
where f.n <> s.n

{{ config(
    materialized='table'
) }}

with date_dimension as (
    select
        to_char(date_day, 'YYYYMMDD')::int as sk_date,
        date_day as date_actual,
        
        extract(year from date_day) as year,
        extract(quarter from date_day) as quarter,
        to_char(date_day, 'YYYY-"Q"Q') as year_quarter,
        extract(month from date_day) as month,
        to_char(date_day, 'Month') as month_name,
        to_char(date_day, 'Mon') as month_name_short,
        to_char(date_day, 'YYYY-MM') as year_month,
        
        extract(week from date_day) as week_of_year,
        extract(day from date_day) as day_of_month,
        extract(dayofweek from date_day) as day_of_week,
        to_char(date_day, 'Day') as day_name,
        to_char(date_day, 'Dy') as day_name_short,
        
        case when extract(dayofweek from date_day) in (0, 6) then true else false end as is_weekend

    from (
        select dateadd(day, seq4(), '2000-01-01'::date) as date_day
        from table(generator(rowcount => 11000))
    )
)

select * from date_dimension
where date_actual <= '2030-12-31'

union all

-- Unknown member (§5.4): NULL order/due/ship dates land here, e.g. unshipped orders.
select
    -1 as sk_date,
    null as date_actual,
    null as year,
    null as quarter,
    null as year_quarter,
    null as month,
    null as month_name,
    null as month_name_short,
    null as year_month,
    null as week_of_year,
    null as day_of_month,
    null as day_of_week,
    null as day_name,
    null as day_name_short,
    null as is_weekend

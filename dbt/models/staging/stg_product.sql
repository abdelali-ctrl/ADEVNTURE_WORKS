{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('production','product') }}
),

cleaned as (
    select
        cast(productid as int) as product_id,
        nullif(trim(name), '') as product_name,
        nullif(trim(productnumber), '') as product_number,
        cast(makeflag as int) as make_flag,
        cast(finishedgoodsflag as int) as finished_goods_flag,
        nullif(trim(color), '') as color,
        cast(safetystocklevel as int) as safety_stock_level,
        cast(reorderpoint as int) as reorder_point,
        cast(standardcost as int) as standard_cost,   
        cast(listprice as int) as list_price,         
        nullif(trim(size), '') as size,
        nullif(trim(sizeunitmeasurecode), '') as size_unit_measure_code,
        nullif(trim(weightunitmeasurecode), '') as weight_unit_measure_code,
        cast(weight as number(15,2)) as weight,       
        cast(daystomanufacture as int) as days_to_manufacture,
        nullif(trim(productline), '') as product_line,
        nullif(trim(class), '') as class,
        nullif(trim(style), '') as style,
        cast(productsubcategoryid as int) as product_subcategory_id,
        cast(productmodelid as int) as product_model_id,
        cast(sellstartdate as date) as sell_start_date,
        cast(sellenddate as date) as sell_end_date,
        cast(discontinueddate as date) as discontinued_date,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('sales', 'SALESORDERHEADER') }}
),

cleaned as (
    select
        cast(salesorderid as int) as sales_order_id,
        cast(revisionnumber as int) as revision_number,
        cast(orderdate as date) as order_date,
        cast(duedate as date) as due_date,
        cast(shipdate as date) as ship_date,
        cast(status as int) as order_status,
        cast(onlineorderflag as int) as online_order_flag,
        nullif(trim(salesordernumber), '') as sales_order_number,
        nullif(trim(purchaseordernumber), '') as purchase_order_number,
        nullif(trim(accountnumber), '') as account_number,
        cast(customerid as int) as customer_id,
        cast(salespersonid as int) as sales_person_id,
        cast(territoryid as int) as territory_id,
        cast(billtoaddressid as int) as bill_to_address_id,
        cast(shiptoaddressid as int) as ship_to_address_id,
        cast(shipmethodid as int) as ship_method_id,
        cast(creditcardid as int) as credit_card_id,
        nullif(trim(creditcardapprovalcode), '') as credit_card_approval_code,
        cast(currencyrateid as int) as currency_rate_id,
        cast(subtotal as number(19,2)) as sub_total,
        cast(taxamt as number(19,2)) as tax_amount,
        cast(freight as number(19,2)) as freight_amount,
        cast(totaldue as number(19,2)) as total_due,
        nullif(trim(comment), '') as order_comment,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned


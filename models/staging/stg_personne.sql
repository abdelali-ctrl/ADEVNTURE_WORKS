{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('person', 'person') }}
),

cleaned as (
    select
        cast(businessentityid as int) as business_entity_id,
        nullif(trim(persontype), '') as person_type,
        cast(namestyle as int) as name_style,
        nullif(trim(title), '') as title,
        nullif(trim(firstname), '') as first_name,
        nullif(trim(middlename), '') as middle_name,
        nullif(trim(lastname), '') as last_name,
        nullif(trim(suffix), '') as suffix,
        cast(emailpromotion as int) as email_promotion,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as timestamp) as modified_date
    from source
)

select * from cleaned
{{ config(
    materialized='table'
) }}

with source as (
    select * from {{ source('HUMANRESOURCES','EMPLOYEE') }}
),

cleaned as (
    select
        cast(businessentityid as int) as business_entity_id,
        nullif(trim(nationalidnumber), '') as national_id_number,
        nullif(trim(loginid), '') as login_id,
        nullif(trim(jobtitle), '') as job_title,
        cast(birthdate as date) as birth_date,
        nullif(trim(maritalstatus), '') as marital_status,
        nullif(trim(gender), '') as gender,
        cast(hiredate as date) as hire_date,
        cast(salariedflag as int) as salaried_flag,
        cast(vacationhours as int) as vacation_hours,
        cast(sickleavehours as int) as sick_leave_hours,
        cast(currentflag as int) as current_flag,
        cast(rowguid as varchar) as row_guid,
        cast(modifieddate as date) as modified_date
    from source
)

select * from cleaned
-- =====================================================================
-- setup.sql  --  Plateforme Snowflake pour adventureworks_dwh
-- Cahier §6 (RBAC least-privilege, warehouse, resource monitor) + §10 (couts).
--
-- A executer UNE FOIS par un ACCOUNTADMIN pour provisionner l'environnement.
-- dbt ne tourne JAMAIS en ACCOUNTADMIN : il utilise le role DBT_ROLE cree ici.
-- Remplacer <MOT_DE_PASSE> avant execution (ou creer l'utilisateur via SSO).
-- =====================================================================

use role accountadmin;

-- --------------------------------------------------------------------
-- 1. Warehouse : XSMALL, auto-suspend 60s (le dataset fait ~150 Mo)
-- --------------------------------------------------------------------
create warehouse if not exists compute_wh
    warehouse_size = 'XSMALL'
    auto_suspend = 60
    auto_resume = true
    initially_suspended = true
    comment = 'Warehouse dbt - dev/prod AdventureWorks';

-- --------------------------------------------------------------------
-- 2. Resource monitor : garde-fou de credits avec suspension
-- --------------------------------------------------------------------
create resource monitor if not exists rm_adventureworks
    with credit_quota = 50
    frequency = monthly
    start_timestamp = immediately
    triggers
        on 75 percent do notify
        on 90 percent do suspend
        on 100 percent do suspend_immediate;

alter warehouse compute_wh set resource_monitor = rm_adventureworks;

-- --------------------------------------------------------------------
-- 3. Base et schemas (medallion)
-- --------------------------------------------------------------------
create database if not exists oltp;
create schema if not exists oltp.silver;   -- staging + intermediate + snapshots
create schema if not exists oltp.gold;     -- etoile + marts
-- Les schemas bronze (SALES, PRODUCTION, PERSON, HUMANRESOURCES, PURCHASING)
-- sont crees par le chargement (voir 03_SNOWFLAKE_DATA_LOADING_GUIDE.md).

-- --------------------------------------------------------------------
-- 4. Role least-privilege pour dbt
-- --------------------------------------------------------------------
create role if not exists dbt_role;

grant usage on warehouse compute_wh to role dbt_role;
grant usage on database oltp to role dbt_role;

-- Lecture sur le bronze
grant usage on all schemas in database oltp to role dbt_role;
grant usage on future schemas in database oltp to role dbt_role;
grant select on all tables in database oltp to role dbt_role;
grant select on future tables in database oltp to role dbt_role;

-- Ecriture sur les schemas transformes
grant all on schema oltp.silver to role dbt_role;
grant all on schema oltp.gold to role dbt_role;
grant all on future tables in schema oltp.silver to role dbt_role;
grant all on future tables in schema oltp.gold to role dbt_role;
grant all on future views in schema oltp.silver to role dbt_role;
grant all on future views in schema oltp.gold to role dbt_role;

-- --------------------------------------------------------------------
-- 5. Utilisateur de service dbt
-- --------------------------------------------------------------------
create user if not exists dbt_user
    password = '<MOT_DE_PASSE>'
    default_role = dbt_role
    default_warehouse = compute_wh
    must_change_password = false
    comment = 'Utilisateur de service dbt';

grant role dbt_role to user dbt_user;

-- --------------------------------------------------------------------
-- 6. Verification
-- --------------------------------------------------------------------
show grants to role dbt_role;

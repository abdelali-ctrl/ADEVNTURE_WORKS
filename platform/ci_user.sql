-- =====================================================================
-- ci_user.sql  --  Utilisateur de service CI (GitHub Actions) par cle RSA
--
-- Cree un role least-privilege et un utilisateur dedie a la CI, qui :
--   - LIT le bronze (OLTP.*)
--   - CREE/ECRIT uniquement les schemas isoles *_ci (silver_ci, gold_ci)
-- La CI ne peut donc jamais ecraser dev/prod.
-- =====================================================================

-- --------------------------------------------------------------------
-- 0. Generer la paire de cles (poste local, une fois) :
--
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
--   openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
--
--   -> Coller le contenu de rsa_key.p8 (cle PRIVEE) dans le GitHub Secret
--      SNOWFLAKE_PRIVATE_KEY.
--   -> Coller le corps de rsa_key.pub (cle PUBLIQUE, SANS les lignes
--      -----BEGIN/END PUBLIC KEY-----) dans le ALTER USER ci-dessous.
--   -> Ne jamais committer ces fichiers (ils sont hors depot).
-- --------------------------------------------------------------------

use role securityadmin;   -- gestion des roles/utilisateurs

-- --------------------------------------------------------------------
-- 1. Role CI least-privilege
-- --------------------------------------------------------------------
create role if not exists dbt_ci_role;
grant role dbt_ci_role to role sysadmin;   -- visibilite pour l'admin

use role accountadmin;    -- pour les grants sur base/warehouse

grant usage on warehouse compute_wh to role dbt_ci_role;
grant usage on database oltp to role dbt_ci_role;

-- Lecture du bronze
grant usage on all schemas in database oltp to role dbt_ci_role;
grant usage on future schemas in database oltp to role dbt_ci_role;
grant select on all tables in database oltp to role dbt_ci_role;
grant select on future tables in database oltp to role dbt_ci_role;

-- Creation des schemas CI isoles (silver_ci, gold_ci) : le role possede ce qu'il cree
grant create schema on database oltp to role dbt_ci_role;

-- --------------------------------------------------------------------
-- 2. Utilisateur de service CI (authentification par cle, pas de mot de passe)
-- --------------------------------------------------------------------
use role securityadmin;

create user if not exists dbt_ci_user
    default_role = dbt_ci_role
    default_warehouse = compute_wh
    comment = 'Utilisateur CI GitHub Actions (cle RSA)';

grant role dbt_ci_role to user dbt_ci_user;

-- Attacher la cle PUBLIQUE (corps de rsa_key.pub, sans en-tetes ni retours a la ligne)
alter user dbt_ci_user set rsa_public_key='<COLLER_LA_CLE_PUBLIQUE_RSA>';

-- --------------------------------------------------------------------
-- 3. Verification
-- --------------------------------------------------------------------
desc user dbt_ci_user;              -- verifier RSA_PUBLIC_KEY_FP renseigne
show grants to role dbt_ci_role;

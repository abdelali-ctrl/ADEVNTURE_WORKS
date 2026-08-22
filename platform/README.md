# Platform — provisionnement Snowflake

Script d'administration : rôle least-privilege, warehouse, resource monitor,
bases/schemas, utilisateur de service dbt.

## Exécution

| Script | Rôle requis | Contenu |
|---|---|---|
| `setup.sql` | ACCOUNTADMIN | warehouse XSMALL / auto-suspend 60, resource monitor, `DBT_ROLE` least-privilege, bases `OLTP` + schemas `silver`/`gold`, `DBT_USER` |

À exécuter une fois, avant l'ingestion (`../ingestion/`). Remplacer `<MOT_DE_PASSE>`
avant exécution (ou créer l'utilisateur via SSO).

## Sécurité

- **Jamais `ACCOUNTADMIN` pour dbt** : le rôle `DBT_ROLE` a des droits limités
  (lecture bronze, écriture `silver`/`gold`).
- **Aucun secret dans le dépôt** : le mot de passe est fourni via la variable
  d'environnement `SNOWFLAKE_PASSWORD` lue par `~/.dbt/profiles.yml` (hors dépôt).
- **Resource monitor** actif avec seuil de suspension pour maîtriser les crédits.

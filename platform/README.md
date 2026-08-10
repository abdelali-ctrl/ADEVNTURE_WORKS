# Platform — provisionnement Snowflake

Scripts d'administration (rôles, warehouse, resource monitor, utilisateurs).

## Ordre d'exécution

| # | Script | Rôle requis | Contenu |
|---|---|---|---|
| 1 | `setup.sql` | ACCOUNTADMIN | warehouse XSMALL/auto-suspend 60, resource monitor, `DBT_ROLE` least-privilege, bases/schemas, `DBT_USER` |
| 2 | `ci_user.sql` | SECURITYADMIN / ACCOUNTADMIN | `DBT_CI_ROLE` + `DBT_CI_USER` (clé RSA), droits limités aux schemas `*_ci` |

## Sécurité des identifiants CI (GitHub Actions)

**Aucun secret dans le dépôt.** La CI s'authentifie par **paire de clés RSA** et lit
les valeurs depuis les **GitHub Secrets**.

### 1. Générer la paire de clés (poste local, une fois)
```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

### 2. Attacher la clé publique à l'utilisateur CI
Coller le corps de `rsa_key.pub` (sans les lignes `-----BEGIN/END-----`) dans le
`ALTER USER ... SET RSA_PUBLIC_KEY=...` de `ci_user.sql`, puis l'exécuter.

### 3. Créer les GitHub Secrets
`Settings > Secrets and variables > Actions` :

| Secret | Valeur |
|---|---|
| `SNOWFLAKE_ACCOUNT` | ex. `ECURZMZ-DV51280` |
| `SNOWFLAKE_USER` | `DBT_CI_USER` |
| `SNOWFLAKE_ROLE` | `DBT_CI_ROLE` |
| `SNOWFLAKE_WAREHOUSE` | `COMPUTE_WH` |
| `SNOWFLAKE_PRIVATE_KEY` | **contenu complet** de `rsa_key.p8` (multi-lignes) |

En CLI : `gh secret set SNOWFLAKE_PRIVATE_KEY < rsa_key.p8`

### Pourquoi c'est sûr
- **Clé RSA** plutôt qu'un mot de passe (recommandation Snowflake pour les services).
- **Utilisateur/rôle dédié** least-privilege : lit le bronze, écrit **uniquement**
  dans les schemas isolés `silver_ci` / `gold_ci` (la macro `generate_schema_name`
  ajoute le suffixe `_ci` en cible `ci`). Un build de PR ne peut rien casser en dev.
- La clé privée est écrite dans un fichier **éphémère** en CI puis **supprimée**
  (`if: always()`), jamais commitée.
- Rotation : régénérer la clé et refaire l'`ALTER USER` en cas de doute.

> Les schemas `*_ci` sont recréés à chaque run. Pour les nettoyer manuellement :
> `drop schema if exists oltp.silver_ci; drop schema if exists oltp.gold_ci;`

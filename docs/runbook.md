# Runbook — deployer, exploiter, depanner

## Provisionnement initial (une fois)

1. `setup.sql` en `ACCOUNTADMIN` (warehouse, resource monitor, `DBT_ROLE`, schemas).
2. Charger le bronze (voir `03_SNOWFLAKE_DATA_LOADING_GUIDE.md`) : historique
   jusqu'au 2013-12-31, delta 2014 retenu pour la demo incrementale.
3. `~/.dbt/profiles.yml` (hors depot) — voir `README.md §5`.

## Cycle quotidien

```bash
dbt deps                 # dependances (dbt_utils)
dbt snapshot             # historisation SCD2 (avant les modeles)
dbt build                # modeles + tests (staging → gold → marts)
dbt source freshness     # fraicheur (stale attendu sur le jeu statique)
```

Reconstruction complete : `dbt build --full-refresh`.

## Chargement incremental (delta 2014)

```bash
dbt run --select fct_sales_order_line fct_sales_order          # incremental (watermark)
dbt run --select fct_sales_order_line fct_sales_order          # rejouer = idempotent (0 changement)
```

## Que faire quand un test echoue

1. **Lire le test** : `target/compiled/.../<test>.sql` contient la requete exacte.
   L'executer dans Snowsight pour voir les lignes fautives.
2. **Reconciliation** (`assert_revenue_*`, `assert_line_net_*`) : ecart au centime
   → verifier la precision numerique du staging (ne pas arrondir avant l'agregat)
   et la logique d'allocation. Voir ADR-0006.
3. **Fan-out** (`unique_*_sk_*` echoue, lignes > attendu) : une jointure de
   dimension a un doublon de cle. Verifier l'unicite de la dimension sur sa cle
   metier (`count(*)` vs `count(distinct cle)`). Voir ADR-0005.
4. **Relationship / orphan FK** : la dimension manque un membre `-1`, ou le fait
   ne coalesce pas vers `-1`.
5. **`invalid identifier`** : un `.yml` teste une colonne que le modele ne produit
   pas (decalage de nom). Aligner le `.yml` sur le SELECT.
6. Corriger, `dbt build --select <modele>+`, confirmer vert.

## Demo "casser un test" (DoD Semaine 2)

Modifier une regle (ex. changer `1 - discount` en `1 + discount`) → `dbt test`
rouge → montrer la requete fautive → annuler → vert.

## Depannage courant

| Symptome | Cause probable | Action |
|---|---|---|
| `Could not connect to Snowflake` | creds / account | `dbt debug` |
| `dbt_cloud.yml not found` | mauvais binaire (dbt Cloud CLI) | utiliser dbt Core (env system) |
| Beaucoup de tests `SKIP` | un test amont en ERROR | corriger l'erreur amont d'abord |
| WARN "node not found" au parse | `name:` d'un `.yml` ≠ fichier `.sql` | renommer, traiter le WARN comme erreur |

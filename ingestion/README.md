# Ingestion — Phase 1 (Bronze)

Scripts de chargement initial des CSV AdventureWorks dans Snowflake, avant dbt.
Correspond a la **Semaine 1** du cahier (§6) et au `03_SNOWFLAKE_DATA_LOADING_GUIDE.md`.

## Architecture (deux etages)

```
CSV AdventureWorks
   │  COPY INTO (brut, une fois)
   ▼
AW_SOURCE           <- "systeme OLTP qu'on ne controle pas", types permissifs (VARCHAR)
   │  pipeline d'extraction (watermark, idempotent)
   ▼
OLTP.<schema>       <- BRONZE lu par dbt, + _loaded_at / _source_file / _batch_id
   (SALES, PRODUCTION, PERSON, HUMANRESOURCES, PURCHASING)
```

## Ordre d'execution

| # | Script | Role |
|---|---|---|
| 0 | `../platform/setup.sql` | warehouse, resource monitor, RBAC, bases |
| 1 | `01_file_formats.sql` | formats de fichier TSV UTF-8 et UTF-16 (sans en-tete) |
| 2 | `02_stage_and_copy.sql` | stage interne, PUT, COPY INTO vers AW_SOURCE |
| 3 | `03_bronze_extract.sql` | AW_SOURCE → bronze : cutoff 2013-12-31 + metadonnees, idempotent |
| 4 | `04_reconcile.sql` | controles de reconciliation (comptages) |

> La DDL brute des 27 tables AW_SOURCE se **transcrit depuis `instawdb.sql`**
> (ordre des colonnes = seul contrat, les fichiers n'ont pas d'en-tete). Voir
> `02_stage_and_copy.sql` pour le patron.

## Les pieges (voir le guide §3)

- Fichiers **tab-delimited** malgre l'extension `.csv`, **sans ligne d'en-tete**.
- Certains fichiers en **UTF-16** (`Person`, `Store`, ...) → format dedie.
- `Person` / `Store` (XML) et `Employee` (`hierarchyid`) : colonnes hostiles,
  **exclues** de l'ingestion (decision tracee dans `docs/decisions.md`).
- `ON_ERROR = 'ABORT_STATEMENT'` : echouer bruyamment, jamais sauter des lignes.

## Chargement etage (initial vs delta)

- **Initial (Semaine 1) :** bronze filtre a `OrderDate <= '2013-12-31'`.
- **Delta (Semaine 3) :** deplacer le cutoff → les commandes 2014 arrivent et
  alimentent les modeles incrementaux. Noter le nombre exact de lignes retenues.

## Definition of Done (Semaine 1)

- [ ] 27 tables dans AW_SOURCE, comptages = `wc -l` des fichiers.
- [ ] Bronze charge avec cutoff 2013-12-31.
- [ ] `_loaded_at`, `_source_file`, `_batch_id` sur chaque table bronze.
- [ ] Rejouer le chargement 2x → 0 doublon (idempotent).
- [ ] 2014 retenu ; nombre de lignes en attente ecrit dans `docs/load_reconciliation.md`.
- [ ] Zero secret dans le depot.

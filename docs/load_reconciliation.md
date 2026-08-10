# Réconciliation de chargement (Phase 1 — Bronze)

Renseigner après avoir exécuté `ingestion/` (voir `ingestion/04_reconcile.sql`).

## Comptages AW_SOURCE vs fichiers (`wc -l`)

| Table | Fichier (lignes) | AW_SOURCE | OK |
|---|---|---|---|
| SalesOrderDetail | | | |
| SalesOrderHeader | | | |
| Customer | | | |
| Product | | | |
| … (27 tables) | | | |

## Effet du cutoff 2013-12-31

| Métrique | Valeur |
|---|---|
| Commandes bronze (initial, ≤ 2013-12-31) | |
| Commandes 2014 en attente (delta Semaine 3) | |
| Total source | |

> Le nombre de commandes 2014 en attente est le résultat attendu du chargement
> incrémental de la Semaine 3.

## Idempotence

Rejouer `03_bronze_extract.sql` → comptages identiques (0 doublon). Confirmé : ☐

## Métadonnées

`_loaded_at`, `_source_file`, `_batch_id` présentes sur chaque table bronze : ☐

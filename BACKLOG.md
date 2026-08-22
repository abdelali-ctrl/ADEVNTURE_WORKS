# BACKLOG

Dette technique et ameliorations tracees (idees hors du perimetre de la semaine
courante). Cf. cahier §7 : le scope gele le lundi, les idees vont ici.

## Priorite haute (pour finir le perimetre du cahier)

- [ ] **Chargement bronze idempotent** + metadonnees `_loaded_at`, `_source_file`,
      `_batch_id` (DoD Semaine 1). Cause racine du double-chargement `ADDRESS`.
- [ ] **Charger la table `CurrencyRate`** en bronze pour reconstituer les montants en
      devise d'origine (le reporting USD + marquage FX est deja fait, ADR-0009).
- [x] ~~**Rebrancher les dimensions SCD2 sur les snapshots**~~ — FAIT (ADR-0010).
      `dim_product`/`dim_customer` sont SCD2, fait en point-in-time, tests SCD2 verts.
- [x] ~~**Multi-devises**~~ — FAIT pour le reporting USD + `is_multicurrency_order`
      (ADR-0009). Reste la conversion (depend du chargement `CurrencyRate`).
- [x] ~~**Tableau de bord**~~ — modele semantique + DAX documentes
      (`docs/powerbi_model.md`) ; repli Streamlit fourni (`streamlit_app.py`). Reste a
      produire le `.pbix` dans Power BI Desktop (Windows).
- [ ] **SCD2 salesperson** : ajouter un snapshot + rebrancher `dim_salesperson`
      (produit/client faits ; salesperson reste Type 1).

## Priorite moyenne (qualite / exploitation)

- [ ] Renommer les modeles mal orthographies (`stg_adress`, `stg_contryregion`,
      `stg_employe`, `stg_personne`, `stg_buisnessentityadress`, `src_purschasing`)
      et adopter la convention `stg_<source>__<entite>`.
- [ ] Relocaliser `int_orderdetail` / `int_orderheader` de `gold/facts/` vers
      `models/intermediate/`, avec listes de colonnes explicites (pas de `select *`).
- [ ] Migrer les tests generiques vers la syntaxe `data_tests:` / `arguments:`
      (supprime les 12 avertissements de depreciation dbt 1.12).
- [ ] `docs/incremental_benchmark.md` : full-refresh vs incremental (temps + credits
      reels depuis `query_history`).
- [x] ~~Tests SCD2 : une seule ligne courante par cle, pas de chevauchement~~ — FAIT
      (`assert_scd2_one_current_row`, `assert_scd2_no_overlapping_ranges`).

## Priorite basse (finitions)

- [ ] `dim_customer` : nom d'affichage/attributs enrichis par type.
- [ ] `fct_order_fulfillment` (snapshot d'accumulation, stretch).
- [ ] Flux git : branche par semaine, PR du vendredi, tags `v0.1` → `v1.0`.
- [ ] Descriptions a 100 % des colonnes (staging inclus).

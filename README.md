# AdventureWorks DWH — Plateforme analytique (Snowflake · dbt · Medallion · Kimball)

Entrepôt de données analytique construit sur la base OLTP **AdventureWorks**.
Les données brutes sont ingérées dans Snowflake, raffinées via une **architecture
medallion** (bronze → silver → gold), puis modélisées en **schéma en étoile de
Kimball** pour répondre aux questions métier (chiffre d'affaires, marge, valeur
client, performance produit, atteinte des quotas).

> État actuel : couches **silver** et **gold** livrées et testées.
> Dernière exécution : `dbt build` → **PASS=303, ERROR=0, SKIP=0, WARN=0** (45 modèles).

---

## 1. Architecture

```
  CSV AdventureWorks  ──COPY INTO──►  BRONZE (RAW / OLTP.*)      1:1 avec la source
                                          │  dbt : stg_*
                                          ▼
                                      SILVER (OLTP.SILVER)       typé, nettoyé, conformé
                                          │  dbt : int_* / dim_* / fct_*
                                          ▼
                                      GOLD (OLTP.GOLD)           étoile de Kimball
                                          ▼
                                      Power BI / BI
```

**Règle porteuse :** chaque couche ne lit que la couche directement au-dessus. Un
modèle gold qui lirait le bronze est une PR rejetée.

| Couche | Schéma Snowflake | Rôle |
|---|---|---|
| Bronze | `OLTP.SALES`, `OLTP.PRODUCTION`, `OLTP.PERSON`, … | Copie fidèle de la source, aucune logique métier |
| Silver | `OLTP.SILVER` | Typage, `snake_case`, déduplication, clés métier résolues, qualité |
| Gold | `OLTP.GOLD` | Faits + dimensions conformes + bridge (schéma en étoile) |

---

## 2. Structure du dépôt

```
adventureworks_dwh/
├── dbt_project.yml            # config projet : staging→silver, intermediate→silver, gold→gold
├── packages.yml               # dépendances (dbt_utils)
├── macros/
│   └── generate_schema_name.sql   # schémas nommés sans préfixe cible
├── models/
│   ├── staging/               # stg_* : 1 modèle par entité source (+ src_*.yml = sources)
│   ├── intermediate/          # logique réutilisable
│   │   ├── int_product_cost_scd.sql    # coût point-in-time (plages de validité)
│   │   └── int_product_price_scd.sql   # prix catalogue point-in-time
│   └── gold/
│       ├── _gold__models.yml           # descriptions + tests (grain, FK, unicité)
│       ├── dimensions/                 # dim_* (11 dimensions, membre inconnu -1)
│       └── facts/                      # fct_* + bridge_* + int_orderheader/detail
├── tests/                     # tests singuliers (réconciliation, règles métier)
├── seeds/  snapshots/  analyses/       # (à venir : snapshots SCD2)
└── target/                    # artefacts compilés (non versionné)
```

### Modèles gold

**Faits**
| Modèle | Type | Grain — *une ligne = …* |
|---|---|---|
| `fct_sales_order_line` | Transaction | une ligne d'une commande |
| `fct_sales_order` | Transaction | une commande (en-tête) |
| `fct_sales_quota` | Transaction | un vendeur × une période de quota |
| `bridge_order_sales_reason` | Bridge | une commande × un motif de vente |

**Dimensions** — `dim_date` (générée, role-playing), `dim_product`, `dim_customer`,
`dim_salesperson`, `dim_territory`, `dim_geography` (role-playing bill-to / ship-to),
`dim_ship_method`, `dim_special_offer`, `dim_sales_reason`, `dim_currency`,
`dim_order_status` (dimension *junk*). Chaque dimension possède un **membre inconnu `-1`**.

---

## 3. Décisions de modélisation clés

- **Coût point-in-time.** La marge utilise le coût en vigueur *à la date de commande*
  (`int_product_cost_scd`, jointure `order_date between valid_from and valid_to`), pas le
  coût actuel. Impact mesuré : **+3,18 M$ (≈34 %)** d'écart vs la version naïve.
- **Fret & taxe.** Répartis au prorata du CA net de la ligne dans `fct_sales_order_line` ;
  la vérité non répartie est conservée dans `fct_sales_order`.
- **Membres inconnus.** Toute FK de fait fait un `coalesce(..., -1)` vers une ligne `-1`
  réelle → aucune ligne de fait perdue en jointure (ex. ~2/3 des commandes sans vendeur).
- **Bridge des motifs.** `allocation_factor = 1 / nombre de motifs` → le CA par motif se
  réconcilie au total.
- **Dimension junk.** `order_status` + `online_order_flag` regroupés dans
  `dim_order_status`.
- **Déduplication défensive.** `stg_address` déduplique (`qualify row_number()`) car le
  bronze `ADDRESS` a été chargé deux fois — en attendant un chargement bronze idempotent.

---

## 4. Prérequis

- Un compte **Snowflake** avec la base `OLTP` et les schémas source chargés (bronze).
- **Python 3.10+** et **dbt-snowflake ≥ 1.7** (`pip install dbt-snowflake`).
- Le package `dbt_utils` (installé via `dbt deps`).

---

## 5. Configuration de la connexion

Créer `~/.dbt/profiles.yml` (hors dépôt — **aucun secret dans git**) :

```yaml
adventureworks_dwh:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "<identifiant_compte>"
      user: "<utilisateur>"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"   # mot de passe via variable d'env
      role: "<role>"            # least-privilege, jamais ACCOUNTADMIN
      warehouse: "<warehouse>"  # XSMALL, auto_suspend = 60
      database: OLTP
      schema: gold              # staging/intermediate surchargent vers 'silver'
      threads: 4
```

Puis, par session :

```powershell
$env:SNOWFLAKE_PASSWORD = "votre-mot-de-passe"   # PowerShell
```

---

## 6. Exécution

```bash
dbt deps            # installe dbt_utils
dbt debug           # vérifie la connexion  → "All checks passed!"
dbt build           # construit tous les modèles + lance tous les tests
```

Commandes utiles :

```bash
dbt run  --select staging      # construire une couche
dbt test --select gold         # tester une couche
dbt build --full-refresh       # reconstruction complète (tables)
dbt docs generate && dbt docs serve   # documentation navigable
```

---

## 7. Tests

- **Tests génériques** (dans les `*.yml`) : `unique`, `not_null`, `relationships` (FK),
  unicité de grain sur chaque fait.
- **Tests singuliers** (dans `tests/`) :
  - `assert_revenue_reconciles_to_source` — CA du fait = CA source, au centime.
  - `assert_line_net_sums_to_header_subtotal` — Σ(net ligne) = SubTotal en-tête.
  - `assert_no_fact_rows_lost` — aucune ligne perdue en jointure.
  - `assert_allocated_freight_sums_to_header` — le fret réparti resomme à l'en-tête.
  - `assert_margin_differs_from_naive_cost` — le coût point-in-time change bien la marge.

---

## 8. Questions métier couvertes (§2.1 du cahier)

1. **CA & marge** par produit / catégorie / territoire / canal / mois (marge point-in-time).
2. **Valeur client** — consommateurs individuels vs revendeurs (base pour CLV / RFM).
3. **Performance produit** — base pour ABC/Pareto, érosion des remises.
4. **Force de vente** — CA vs quota par vendeur et trimestre (`fct_sales_quota`).

---

## 9. Reste à faire (feuille de route)

- [ ] **Snapshots SCD2** sur produit / client / prix (`dbt snapshot`).
- [ ] **Chargement bronze idempotent** (cause racine du double-chargement `ADDRESS`).
- [ ] **Multi-devises** : porter `sk_currency` sur les faits, déclarer la devise de reporting.
- [ ] Chargement **incrémental** des faits (watermark `ModifiedDate`) + delta 2014.
- [ ] **Marts** métier : CLV+RFM, produit ABC/Pareto, atteinte des quotas.
- [ ] **Tableau de bord Power BI** (≥ 4 pages) et modèle sémantique.
- [ ] `/docs` : `architecture.md`, `metrics.md`, `runbook.md`, `decisions.md` (ADR).
- [ ] Renommer les modèles mal orthographiés ; relocaliser les `int_*` en `intermediate/`.

---

## 10. Conventions

`bronze` → `stg_` → `int_` → `dim_`/`fct_`/`bridge_` → `mart_` ·
clés : `sk_` (substitution), `nk_` (naturelle), membre inconnu = `-1` ·
`snake_case` à partir de silver · SQL : CTE, colonnes explicites, mots-clés en minuscule ·
secrets par variables d'environnement uniquement.

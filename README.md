# AdventureWorks DWH — Plateforme analytique (Snowflake · dbt · Medallion · Kimball)

Entrepôt de données analytique construit sur la base OLTP **AdventureWorks**.
Ingestion des CSV dans Snowflake, raffinage via **architecture medallion**
(bronze → silver → gold), modélisation en **schéma en étoile de Kimball**, et
restitution BI. Répond aux questions métier : chiffre d'affaires, marge (au coût
historique), valeur client (CLV/RFM), performance produit (ABC/Pareto), atteinte
des quotas.

> **État : projet complet et réconcilié.** Dernier `dbt build` →
> **PASS=322, ERROR=0, SKIP=0, WARN=0** (45 modèles, snapshots SCD2, 258 tests).

---

## 1. Structure du dépôt

Le **projet dbt** est isolé dans `dbt/` ; tout ce qui n'est pas dbt est dans des
dossiers dédiés.

```
adventureworks_dwh/            (racine du dépôt git)
├── dbt/                       ← PROJET DBT (dbt_project.yml, models/, macros/, tests/, snapshots/, seeds/)
├── ingestion/                 ← Phase 1 : chargement bronze (file formats, COPY INTO, cutoff, métadonnées)
├── platform/                  ← setup.sql (RBAC least-privilege, warehouse, resource monitor)
├── dashboard/                 ← streamlit_app.py (repli BI, 4 pages)
├── docs/                      ← architecture, metrics, runbook, decisions (ADR), source_profile, powerbi_model
├── BACKLOG.md                 ← dette technique / reste à faire
└── README.md
```

### Contenu du projet dbt (`dbt/`)

```
dbt/
├── models/
│   ├── staging/          stg_* : 1 modèle par entité source (+ src_*.yml = sources)
│   ├── intermediate/     int_product_cost_scd / int_product_price_scd (point-in-time)
│   └── gold/
│       ├── dimensions/   dim_* (11 dims, membre inconnu -1 ; product/customer en SCD2)
│       ├── facts/        fct_* + bridge_* + int_orderheader/detail
│       └── marts/        mart_customer_clv_rfm, mart_product_abc_pareto, mart_seller_quota_attainment
├── snapshots/            snap_product, snap_customer, snap_product_pricing (SCD2)
└── tests/                tests singuliers (réconciliation, règles métier, SCD2)
```

---

## 2. Architecture (medallion + Kimball)

```
CSV AdventureWorks ─COPY INTO─► AW_SOURCE ─pipeline─► BRONZE (OLTP.*) ─stg_*─► SILVER ─dim_/fct_─► GOLD ─► BI
                               (landing brut)        (+ métadonnées)          (typé)     (étoile)
```

**Règle porteuse :** chaque couche ne lit que la couche directement au-dessus.

| Couche | Schéma Snowflake | Rôle |
|---|---|---|
| Landing | `AW_SOURCE.*` | copie brute des CSV (VARCHAR) — voir `ingestion/` |
| Bronze | `OLTP.SALES`, `OLTP.PRODUCTION`, `OLTP.PERSON`, … | + `_loaded_at` / `_source_file` / `_batch_id`, cutoff 2013-12-31 |
| Silver | `OLTP.SILVER` | `stg_*`, `int_*`, snapshots SCD2 |
| Gold | `OLTP.GOLD` | `dim_*`, `fct_*`, `bridge_*`, `mart_*` |

---

## 3. Décisions de modélisation clés (voir `docs/decisions.md`)

- **Coût point-in-time** — marge au coût *à la date de commande*. Impact : **+3,18 M$ (~34 %)** vs coût actuel.
- **SCD2 de bout en bout** — `dim_product` / `dim_customer` historisées via snapshots ; faits joints en point-in-time.
- **Membres inconnus `-1`** sur toutes les dimensions → aucune ligne de fait perdue.
- **Fret/taxe** répartis au prorata (fait ligne) + conservés bruts (fait en-tête).
- **Bridge M:N** des motifs avec `allocation_factor`.
- **Multi-devises** — reporting USD, commandes FX marquées (`is_multicurrency_order`).
- **Junk dim** `order_status` ; dédup défensive `stg_address` (bronze double-chargé).

---

## 4. Prérequis

- Compte **Snowflake** (base `OLTP` chargée — voir `ingestion/`).
- **Python 3.10+** et **dbt-snowflake ≥ 1.7** (`pip install dbt-snowflake`).

---

## 5. Connexion

Créer `~/.dbt/profiles.yml` (hors dépôt — **aucun secret dans git**) :

```yaml
adventureworks_dwh:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "<identifiant_compte>"
      user: "<utilisateur>"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: "<role>"            # least-privilege (DBT_ROLE), jamais ACCOUNTADMIN
      warehouse: "<warehouse>"  # XSMALL, auto_suspend = 60
      database: OLTP
      schema: gold              # staging/intermediate surchargent vers 'silver'
      threads: 4
```

```powershell
$env:SNOWFLAKE_PASSWORD = "votre-mot-de-passe"   # PowerShell
```

---

## 6. Exécution

### Phase 1 — Ingestion (une fois)
```sql
-- dans Snowsight, dans l'ordre :
platform/setup.sql            -- warehouse, resource monitor, RBAC, bases
ingestion/01_file_formats.sql
ingestion/02_stage_and_copy.sql
ingestion/03_bronze_extract.sql   -- cutoff 2013-12-31 + métadonnées
ingestion/04_reconcile.sql
```

### Phases 2-4 — dbt (**depuis `dbt/`**)
```bash
cd dbt
dbt deps
dbt debug            # "All checks passed!"
dbt snapshot         # historisation SCD2 (avant les modèles)
dbt build            # staging → gold → marts + tous les tests
dbt source freshness
dbt docs generate && dbt docs serve
```

Reconstruction complète : `dbt build --full-refresh`.
Delta 2014 (incrémental) : voir `docs/runbook.md`.

---

## 7. Tests

- **Génériques** : `unique`, `not_null`, `relationships` (FK), unicité de grain sur chaque fait.
- **Singuliers** (`dbt/tests/`) : réconciliation CA↔source, net ligne↔en-tête, fret réparti,
  aucune ligne perdue, marge ≠ coût naïf, **SCD2** (une ligne courante, pas de chevauchement).

---

## 8. Questions métier couvertes (§2.1)

CA & marge (point-in-time) · valeur client CLV/RFM · performance produit ABC/Pareto ·
force de vente vs quota. Dashboard : `dashboard/streamlit_app.py` + modèle Power BI
documenté (`docs/powerbi_model.md`).

---

## 9. Reste à faire

Voir `BACKLOG.md`. Points ouverts : chargement bronze idempotent depuis les CSV réels,
chargement de `CurrencyRate` (conversion FX), SCD2 salesperson, `.pbix` Power BI natif.

---

## 10. Conventions

`bronze` → `stg_` → `int_` → `dim_`/`fct_`/`bridge_` → `mart_` · clés : `sk_`
(substitution), `nk_` (naturelle), inconnu = `-1` · `snake_case` dès silver ·
SQL en CTE, colonnes explicites · secrets par variables d'environnement uniquement.

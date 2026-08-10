# Architecture

## Vue d'ensemble (medallion + Kimball)

```
CSV AdventureWorks ──COPY INTO──► BRONZE ──stg_*──► SILVER ──dim_/fct_/bridge_──► GOLD ──► BI
      (source)                    (RAW 1:1)         (typé/conformé)   (etoile Kimball)
```

**Regle porteuse :** chaque couche ne lit que la couche directement au-dessus.
Un modele gold qui lirait le bronze = PR rejetee.

## Couches

| Couche | Schema Snowflake | Materialisation | Contenu |
|---|---|---|---|
| Bronze | `OLTP.SALES`, `OLTP.PRODUCTION`, `OLTP.PERSON`, `OLTP.HUMANRESOURCES`, `OLTP.PURCHASING` | tables (chargees) | copie fidele de la source |
| Silver | `OLTP.SILVER` | table | `stg_*`, `int_*`, snapshots SCD2 |
| Gold | `OLTP.GOLD` | table / incremental | `dim_*`, `fct_*`, `bridge_*`, `mart_*` |

## Le schema en etoile (gold)

- **Faits** : `fct_sales_order_line` (grain ligne, incremental), `fct_sales_order`
  (grain en-tete, incremental), `fct_sales_quota` (vendeur × periode),
  `bridge_order_sales_reason` (M:N motifs).
- **Dimensions** : `dim_date` (generee, role-playing commande/echeance/expedition),
  `dim_product`, `dim_customer`, `dim_salesperson`, `dim_territory`,
  `dim_geography` (role-playing bill-to/ship-to), `dim_ship_method`,
  `dim_special_offer`, `dim_sales_reason`, `dim_currency`, `dim_order_status` (junk).
- Chaque dimension a un **membre inconnu `-1`** ; les faits joignent en `left join`
  + `coalesce(..., -1)` → aucune ligne perdue.

## Point-in-time (coeur du modele)

`int_product_cost_scd` / `int_product_price_scd` ferment les plages de validite de
`ProductCostHistory` / `ProductListPriceHistory`. Le fait ligne joint sur
`order_date between valid_from and valid_to` → la marge utilise le cout **a la date
de commande**. Impact mesure : **+3,18 M$ (~34 %)** vs le cout actuel naif.

## Historisation (SCD2)

`dbt snapshot` maintient `snap_product`, `snap_customer`, `snap_product_pricing`
(strategie `check`) dans `OLTP.SILVER`, avec `dbt_valid_from/to`.

## Chargement incremental

Les faits sont `incremental` (strategie `merge`, cle `sk_*`) avec un watermark sur
`modified_date` et un rattrapage de 3 jours (late-arriving data). Rejouer le
chargement est idempotent (verifie : 2 executions → 0 ligne modifiee).

## Lignage

Generer le graphe navigable : `dbt docs generate && dbt docs serve`.

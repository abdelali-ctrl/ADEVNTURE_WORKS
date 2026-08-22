# Modèle sémantique Power BI

Guide pour construire le rapport Power BI natif (Windows) sur le schéma en étoile
gold. Power BI Desktop étant une application Windows, le fichier `.pbix` se
construit dans l'outil ; ce document fournit tout le nécessaire (connexion,
relations, mesures DAX) pour le reproduire à l'identique. Repli multiplateforme :
`streamlit_app.py`.

## 1. Connexion

- **Obtenir les données** → **Snowflake**.
- Serveur : `<compte>.snowflakecomputing.com` · Entrepôt : `COMPUTE_WH`.
- Base `OLTP`, schéma `GOLD`.
- Mode : **Import** (dataset ~150 Mo, tient en mémoire). DirectQuery possible si
  besoin de temps réel.
- Tables à charger : `fct_sales_order_line`, `fct_sales_order`, `fct_sales_quota`,
  `bridge_order_sales_reason`, et toutes les `dim_*`, plus les `mart_*`.

## 2. Relations (schéma en étoile)

Créer des relations **plusieurs-à-un**, sens unique (dimension → fait) :

| Fait (plusieurs) | Colonne | Dimension (un) | Colonne |
|---|---|---|---|
| fct_sales_order_line | sk_product | dim_product | sk_product |
| fct_sales_order_line | sk_customer | dim_customer | sk_customer |
| fct_sales_order_line | sk_salesperson | dim_salesperson | sk_salesperson |
| fct_sales_order_line | sk_territory | dim_territory | sk_territory |
| fct_sales_order_line | sk_special_offer | dim_special_offer | sk_special_offer |
| fct_sales_order_line | sk_ship_method | dim_ship_method | sk_ship_method |
| fct_sales_order_line | sk_order_status | dim_order_status | sk_order_status |
| fct_sales_order_line | sk_currency | dim_currency | sk_currency |
| fct_sales_order_line | sk_order_date | dim_date | sk_date |

**Rôles de date (role-playing) :** créer des copies de `dim_date`
(`dim_date_commande`, `dim_date_echeance`, `dim_date_expedition`) et relier
respectivement `sk_order_date`, `sk_due_date`, `sk_ship_date`. Idem pour
`dim_geography` (bill-to / ship-to).

**Bridge des motifs :** `fct_sales_order_line[sales_order_id]` →
`bridge_order_sales_reason[sales_order_id]` (plusieurs-à-plusieurs) →
`dim_sales_reason[sk_sales_reason]`. Toujours pondérer par `allocation_factor`.

Marquer `dim_date` comme **table de dates** (Modélisation → Marquer comme table de
dates, colonne `date_actual`).

## 3. Mesures DAX

```DAX
-- Base
Chiffre d'affaires = SUM ( fct_sales_order_line[net_amount] )
Marge brute        = SUM ( fct_sales_order_line[gross_margin] )
Cout total         = SUM ( fct_sales_order_line[total_cost] )
Quantite           = SUM ( fct_sales_order_line[order_qty] )
Nb commandes       = DISTINCTCOUNT ( fct_sales_order_line[sales_order_id] )

Taux de marge % =
DIVIDE ( [Marge brute], [Chiffre d'affaires] )

Panier moyen =
DIVIDE ( [Chiffre d'affaires], [Nb commandes] )

-- Time intelligence (necessite dim_date marquee comme table de dates)
CA AC (annee en cours) =
CALCULATE ( [Chiffre d'affaires], DATESYTD ( dim_date[date_actual] ) )

CA N-1 =
CALCULATE ( [Chiffre d'affaires], SAMEPERIODLASTYEAR ( dim_date[date_actual] ) )

Croissance CA % =
DIVIDE ( [Chiffre d'affaires] - [CA N-1], [CA N-1] )

-- Motifs de vente (via le bridge, pondere)
CA par motif =
SUMX (
    bridge_order_sales_reason,
    bridge_order_sales_reason[allocation_factor]
        * CALCULATE ( [Chiffre d'affaires],
            fct_sales_order_line[sales_order_id] = EARLIER ( bridge_order_sales_reason[sales_order_id] ) )
)

-- Quota (mesures sur mart_seller_quota_attainment)
Quota            = SUM ( mart_seller_quota_attainment[quota_amount] )
Realise          = SUM ( mart_seller_quota_attainment[actual_revenue] )
Taux d'atteinte %= DIVIDE ( [Realise], [Quota] )
```

## 4. Pages (≥ 4, cahier §6)

1. **Exécutif** — CA, marge, taux de marge, croissance N-1 ; CA par mois ; CA par
   catégorie ; carte par territoire.
2. **Client** — segments RFM (mart_customer_clv_rfm), top clients par CLV,
   répartition particuliers vs revendeurs.
3. **Produit** — courbe de Pareto (CA cumulé), classes ABC, top produits, marge %.
4. **Force de vente** — réalisé vs quota par vendeur et trimestre, taux d'atteinte.

## 5. Réconciliation (obligatoire)

Chaque KPI d'en-tête doit correspondre à l'entrepôt **exactement**. Contrôle :
`[Chiffre d'affaires]` total = `109 846 381,40 $` (= `SUM(net_amount)` dans gold).

## 6. Multi-devises

Le reporting est en **USD** (`dim_currency`, tous les faits pointent USD). Les
commandes passées dans une autre devise sont marquées `is_multicurrency_order` ;
la reconstitution des montants en devise d'origine attend le chargement de la table
`CurrencyRate` (voir ADR-0009).

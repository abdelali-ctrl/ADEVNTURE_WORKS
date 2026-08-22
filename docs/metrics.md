# Dictionnaire metier (metrics)

Definitions faisant autorite. Tout KPI de dashboard doit se reconcilier a ces
mesures dans l'entrepot.

## Mesures de vente (fct_sales_order_line)

| Mesure | Definition | Formule |
|---|---|---|
| `gross_amount` | CA brut ligne (avant remise) | `qty × unit_price` |
| `discount_amount` | Montant de remise | `qty × unit_price × discount_pct` |
| `net_amount` | **CA net ligne** | `qty × unit_price × (1 − discount_pct)` |
| `unit_standard_cost` | Cout unitaire **a la date de commande** | `int_product_cost_scd` (point-in-time) |
| `total_cost` | Cout total ligne | `unit_standard_cost × qty` |
| `gross_margin` | **Marge brute** | `net_amount − total_cost` |
| `allocated_freight` | Fret reparti au prorata | `freight_header × (net_amount / net_commande)` |
| `allocated_tax` | Taxe repartie au prorata | idem avec la taxe |
| `effective_discount_pct` | Remise reelle vs prix catalogue | `1 − (unit_price / list_price_at_order_date)` |

**Regle :** la marge utilise le cout **historique** (point-in-time), jamais
`dim_product.standard_cost` (cout actuel). Difference mesuree : ~34 %.

## Mesures d'en-tete (fct_sales_order)

`subtotal`, `tax_amount`, `freight`, `total_due` (valeurs source non reparties),
`days_to_ship`, `days_promised`, `is_shipped_on_time`, `subtotal_variance`
(controle de reconciliation, doit etre ~0).

## Client — CLV / RFM (mart_customer_clv_rfm)

| Terme | Definition |
|---|---|
| Recence (`recency_days`) | jours entre la derniere commande et la date de reference (max des dates de commande) |
| Frequence (`frequency_orders`) | nombre de commandes distinctes |
| Montant (`monetary_total`) | somme des `total_due` |
| Scores `r/f/m_score` | quintiles 1..5 (recence inversee) |
| `rfm_segment` | Champions / Loyaux / Nouveaux / A risque / A reconquerir / Dormants |
| `lifetime_margin` | proxy CLV = marge brute cumulee du client |

## Produit — ABC / Pareto (mart_product_abc_pareto)

| Classe | Regle (CA cumule) |
|---|---|
| A | jusqu'a 80 % |
| B | 80 % → 95 % |
| C | 95 % → 100 % |

`margin_pct = margin / revenue`, `revenue_rank`, `cumulative_revenue_pct`.

## Force de vente (mart_seller_quota_attainment)

Grain vendeur × trimestre. `attainment_pct = actual_revenue / quota_amount`,
`variance_to_quota`, `attainment_status` (Atteint / Non atteint / Sans quota).

## Reconciliation (invariants testes)

- `SUM(net_amount)` fait = CA source, au centime.
- `SUM(net_amount)` par commande = `subtotal` en-tete.
- `SUM(allocated_freight)` par commande = `freight` en-tete.
- `count(fct_sales_order_line)` = nombre de lignes source (aucune perte).

# Profil des sources

Comptages verifies contre Snowflake (bronze `OLTP.*`).

## Volumes des tables cles

| Table source | Lignes | PK distinctes | Note |
|---|---|---|---|
| `SALES.SALESORDERDETAIL` | 121 317 | 121 317 | grain ligne, PK propre |
| `SALES.SALESORDERHEADER` | 31 465 | 31 465 | grain commande |
| `SALES.CUSTOMER` | 19 820 | 19 820 | 2 types (personne/magasin) |
| `PRODUCTION.PRODUCT` | 504 | 504 | |
| `PERSON.ADDRESS` | **39 228** | **19 614** | **double-charge (×2)** ⚠ |
| `PRODUCTION.PRODUCTCOSTHISTORY` | 395 | 395 | plages non chevauchantes |
| `PRODUCTION.PRODUCTLISTPRICEHISTORY` | 395 | 395 | |

## Les trois anomalies trouvees

1. **`ADDRESS` charge deux fois** (39 228 lignes / 19 614 ids) — chargement bronze
   non idempotent. Sans garde-fou, provoque un fan-out du fait (×4 via bill+ship).
   → dedup defensive dans `stg_address` ; cause racine a corriger (chargement bronze).
2. **`stg_creditcard` lisait la source `CURRENCY`** (copier-coller) — retournait des
   colonnes de devise, faisant echouer tous ses tests. → repointe vers `CREDITCARD`.
3. **Precision `money` tronquee** — `unit_price` caste en `number(19,2)` cassait la
   reconciliation par commande (2 390 ecarts). → `number(19,4)`.

## Caracteristiques metier notables

- **FK nullable :** ~2/3 des commandes (en ligne) ont `SalesPersonID` NULL → gere
  par le membre inconnu `-1`, pas par un filtre.
- **Deux types de clients :** `Customer` pointe vers une Personne OU un Magasin →
  conformes dans `dim_customer.customer_type`.
- **Multi-devises :** la plupart des commandes sont en USD avec un taux NULL ;
  celles avec `CurrencyRateID` sont a traiter (ADR-0009, ouverte).
- **Hierarchie snowflakee :** Product → Subcategory → Category (3 tables)
  denormalisee dans `dim_product`.

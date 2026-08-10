# Journal des decisions (ADR)

Format : contexte → decision → alternative → consequence.

## ADR-0001 — Cout point-in-time pour la marge
**Contexte.** `Product.StandardCost` est le cout *actuel*. Coster une commande 2012
avec le cout d'aujourd'hui fausse toute marge historique.
**Decision.** Joindre `ProductCostHistory` (plages de validite fermees dans
`int_product_cost_scd`) sur `order_date between valid_from and valid_to`.
**Alternative.** Utiliser le cout actuel — plus simple, mais faux de ~34 %.
**Consequence.** Marge fiable ; un test garantit qu'elle differe du cout naif.

## ADR-0002 — Fret/taxe : allouer ET conserver l'en-tete
**Contexte.** Fret et taxe n'existent qu'au grain en-tete.
**Decision.** Repartir au prorata du CA net dans `fct_sales_order_line` (colonnes
`allocated_*`) ET conserver la valeur brute dans `fct_sales_order`.
**Alternative.** Ne pas allouer (plus honnete mais "marge par produit" incomplete).
**Consequence.** Analyse par produit possible ; la verite non repartie reste
disponible et se reconcilie (test).

## ADR-0003 — Membre inconnu `-1` plutot que filtre
**Contexte.** ~2/3 des commandes sont en ligne, sans vendeur.
**Decision.** Ligne `-1` dans chaque dimension + `coalesce(fk, -1)`.
**Alternative.** `WHERE fk is not null` — supprime silencieusement des lignes.
**Consequence.** Aucune ligne de fait perdue ; les totaux restent justes.

## ADR-0004 — Bridge des motifs avec facteur d'allocation
**Contexte.** Une commande peut avoir plusieurs motifs de vente (M:N).
**Decision.** `bridge_order_sales_reason` avec `allocation_factor = 1/n`.
**Alternative.** Double-compter et documenter — reporte la charge sur le lecteur.
**Consequence.** `sum(mesure × allocation_factor)` se reconcilie au total.

## ADR-0005 — Test d'unicite de grain obligatoire sur chaque fait
**Contexte.** Un bronze `ADDRESS` double-charge + une jointure junk-dim sur la
mauvaise cle ont provoque un fan-out ×8 silencieux.
**Decision.** Test `unique` sur la cle de substitution de chaque fait, non negociable.
**Consequence.** Toute explosion future est detectee immediatement.

## ADR-0006 — Precision numerique en staging
**Contexte.** Caster `unit_price` en `number(19,2)` tronque la precision `money`
(4 decimales) → le net par ligne derive du SubTotal en-tete (2 390 commandes).
**Decision.** Conserver `number(19,4)` en staging ; n'arrondir qu'a l'affichage.
**Consequence.** Reconciliation au centime.

## ADR-0007 — Deduplication defensive en staging
**Contexte.** Le bronze `ADDRESS` n'est pas idempotent (charge 2 fois).
**Decision.** `qualify row_number()` dans `stg_address` en attendant un chargement
bronze idempotent (dette tracee au BACKLOG).
**Alternative.** Corriger seulement le bronze — correct mais laisse silver fragile.
**Consequence.** Silver fiable des maintenant ; la cause racine reste a corriger.

## ADR-0008 — Degenerate dimension pour `sales_order_number`
**Contexte.** Le numero de commande identifie la transaction mais n'a pas
d'attributs.
**Decision.** Le porter sur le fait, sans dimension dediee.
**Consequence.** Moins de jointures ; pas de dimension a une colonne.

## ADR-0009 — Devise de reporting (USD)
**Contexte.** ~44 % des commandes (13 976 / 31 465) portent un `CurrencyRateID`
(passees dans une autre devise). La table `CurrencyRate` n'est pas chargee en bronze.
**Decision.** Reporting en **USD**. Les faits portent `sk_currency` (→ `dim_currency`,
USD) et un indicateur `is_multicurrency_order` + le `currency_rate_id` degenere.
**Statut : implemente** pour le reporting USD et le marquage FX. La reconstitution
des montants en devise d'origine attend le chargement de `CurrencyRate` (BACKLOG).
**Consequence.** Agregations correctes en USD ; les commandes multi-devises sont
identifiables sans fabriquer de taux de change.

## ADR-0011 — Exclusion des colonnes hostiles à l'ingestion
**Contexte.** `Person`/`Store` portent des colonnes XML (newlines/tabs embarqués)
et `Employee` un `hierarchyid` binaire — ingérables mais inutiles au star schema.
**Decision.** Les **exclure** à l'ingestion (option (a) du guide §3). Cela plie la
règle "bronze 1:1 avec la source", d'où cette trace.
**Alternative.** Charger en texte brut et ne jamais y toucher — conserve la règle
mais alourdit le bronze sans usage.
**Consequence.** Bronze plus propre ; l'écart au 1:1 est documenté et volontaire.

## ADR-0010 — SCD2 de bout en bout via snapshots
**Contexte.** Les dimensions produit/client doivent etre historisees (Type 2).
**Decision.** `dbt snapshot` (strategie `check`) alimente `snap_product`/`snap_customer` ;
`dim_product`/`dim_customer` exposent `valid_from`/`valid_to`/`is_current` au grain
version, et le fait joint en point-in-time sur la date de commande. Le `valid_from`
de la 1ere version est ramene a 1900-01-01 pour couvrir l'historique anterieur a la
capture du snapshot.
**Consequence.** Un fait est rattache a la version de dimension en vigueur a la date
de commande ; teste par `assert_scd2_one_current_row` et `assert_scd2_no_overlapping_ranges`.

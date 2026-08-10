"""
Tableau de bord AdventureWorks — Streamlit-in-Snowflake.

Repli BI (Power BI etant Windows-only). 4 pages : Executif, Client, Produit,
Force de vente. Alimente par le schema en etoile gold (OLTP.GOLD).

Deploiement : Snowsight > Streamlit > New app, coller ce fichier, warehouse
COMPUTE_WH, base OLTP, schema GOLD. Chaque KPI se reconcilie a l'entrepot.
"""

import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="AdventureWorks — Analytics", layout="wide")
session = get_active_session()


@st.cache_data(ttl=600)
def q(sql: str):
    return session.sql(sql).to_pandas()


st.title("AdventureWorks — Plateforme analytique")
page = st.sidebar.radio(
    "Page",
    ["Executif", "Client (CLV/RFM)", "Produit (ABC/Pareto)", "Force de vente"],
)

# --------------------------------------------------------------- EXECUTIF
if page == "Executif":
    st.header("Vue executive")
    kpi = q("""
        select
            round(sum(net_amount), 0)   as revenue,
            round(sum(gross_margin), 0) as margin,
            count(distinct sales_order_id) as orders
        from oltp.gold.fct_sales_order_line
    """).iloc[0]

    c1, c2, c3 = st.columns(3)
    c1.metric("Chiffre d'affaires", f"${kpi.REVENUE:,.0f}")
    c2.metric("Marge brute (point-in-time)", f"${kpi.MARGIN:,.0f}")
    c3.metric("Commandes", f"{kpi.ORDERS:,.0f}")

    st.subheader("CA par mois")
    st.line_chart(
        q("""
            select d.year_month as mois, round(sum(f.net_amount),0) as ca
            from oltp.gold.fct_sales_order_line f
            join oltp.gold.dim_date d on f.sk_order_date = d.sk_date
            group by 1 order by 1
        """),
        x="MOIS", y="CA",
    )

    st.subheader("CA par categorie de produit")
    st.bar_chart(
        q("""
            select coalesce(p.category_name,'(n/a)') as categorie,
                   round(sum(f.net_amount),0) as ca
            from oltp.gold.fct_sales_order_line f
            join oltp.gold.dim_product p on f.sk_product = p.sk_product
            group by 1 order by 2 desc
        """),
        x="CATEGORIE", y="CA",
    )

# --------------------------------------------------------------- CLIENT
elif page == "Client (CLV/RFM)":
    st.header("Valeur client — RFM & CLV")
    seg = q("""
        select rfm_segment, count(*) as clients,
               round(sum(lifetime_margin),0) as marge_cumulee
        from oltp.gold.mart_customer_clv_rfm
        group by 1 order by 3 desc
    """)
    c1, c2 = st.columns(2)
    c1.subheader("Clients par segment")
    c1.bar_chart(seg, x="RFM_SEGMENT", y="CLIENTS")
    c2.subheader("Marge cumulee par segment")
    c2.bar_chart(seg, x="RFM_SEGMENT", y="MARGE_CUMULEE")

    st.subheader("Top 20 clients par CLV (marge cumulee)")
    st.dataframe(
        q("""
            select customer_display_name as client, customer_type as type,
                   frequency_orders as commandes,
                   round(monetary_total,0) as montant,
                   round(lifetime_margin,0) as clv_marge, rfm_segment as segment
            from oltp.gold.mart_customer_clv_rfm
            order by lifetime_margin desc limit 20
        """),
        use_container_width=True,
    )

# --------------------------------------------------------------- PRODUIT
elif page == "Produit (ABC/Pareto)":
    st.header("Performance produit — ABC / Pareto")
    abc = q("""
        select abc_class, count(*) as produits,
               round(sum(revenue),0) as ca, round(sum(margin),0) as marge
        from oltp.gold.mart_product_abc_pareto
        group by 1 order by 1
    """)
    c1, c2, c3 = st.columns(3)
    for _, r in abc.iterrows():
        st.write(f"**Classe {r.ABC_CLASS}** — {r.PRODUITS} produits · "
                 f"CA ${r.CA:,.0f} · marge ${r.MARGE:,.0f}")

    st.subheader("Courbe de Pareto (CA cumule)")
    st.line_chart(
        q("""
            select revenue_rank as rang,
                   round(cumulative_revenue_pct*100,2) as ca_cumule_pct
            from oltp.gold.mart_product_abc_pareto
            order by revenue_rank
        """),
        x="RANG", y="CA_CUMULE_PCT",
    )

    st.subheader("Top 20 produits")
    st.dataframe(
        q("""
            select product_name as produit, category_name as categorie,
                   round(revenue,0) as ca, round(margin_pct*100,1) as marge_pct,
                   abc_class as classe
            from oltp.gold.mart_product_abc_pareto
            order by revenue desc limit 20
        """),
        use_container_width=True,
    )

# --------------------------------------------------------------- VENTE
else:
    st.header("Force de vente — realise vs quota")
    st.dataframe(
        q("""
            select salesperson_name as vendeur, year_quarter as trimestre,
                   round(quota_amount,0) as quota,
                   round(actual_revenue,0) as realise,
                   round(attainment_pct*100,1) as atteinte_pct,
                   attainment_status as statut
            from oltp.gold.mart_seller_quota_attainment
            where quota_amount is not null
            order by year_quarter, attainment_pct desc
        """),
        use_container_width=True,
    )

    st.subheader("Taux d'atteinte moyen par trimestre")
    st.bar_chart(
        q("""
            select year_quarter as trimestre,
                   round(avg(attainment_pct)*100,1) as atteinte_moy_pct
            from oltp.gold.mart_seller_quota_attainment
            where quota_amount is not null
            group by 1 order by 1
        """),
        x="TRIMESTRE", y="ATTEINTE_MOY_PCT",
    )

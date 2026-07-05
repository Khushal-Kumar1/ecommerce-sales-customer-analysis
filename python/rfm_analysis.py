"""
RFM Segmentation & Cohort Analysis (Python/pandas)
Reproduces the SQL-based segmentation in sql/queries.sql (Q3, Q4) using pandas,
so the same finding is validated two ways.
"""
import sqlite3
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

conn = sqlite3.connect("/home/claude/ecommerce-project/data/ecommerce.db")
orders = pd.read_sql_query(
    "SELECT * FROM orders WHERE order_status <> 'Cancelled'", conn,
    parse_dates=["order_date"]
)

snapshot_date = orders["order_date"].max() + pd.Timedelta(days=1)

rfm = orders.groupby("customer_id").agg(
    recency=("order_date", lambda x: (snapshot_date - x.max()).days),
    frequency=("order_id", "nunique"),
    monetary=("order_total", "sum")
).reset_index()

rfm["r_score"] = pd.qcut(rfm["recency"], 5, labels=[5, 4, 3, 2, 1]).astype(int)
rfm["f_score"] = pd.qcut(rfm["frequency"].rank(method="first"), 5, labels=[1, 2, 3, 4, 5]).astype(int)
rfm["m_score"] = pd.qcut(rfm["monetary"], 5, labels=[1, 2, 3, 4, 5]).astype(int)


def segment(row):
    if row.r_score >= 4 and row.f_score >= 4 and row.m_score >= 4:
        return "Champion"
    elif row.r_score >= 3 and row.f_score >= 3:
        return "Loyal Customer"
    elif row.r_score <= 2 and row.f_score >= 3:
        return "At Risk"
    elif row.r_score <= 2 and row.f_score <= 2:
        return "Lost"
    return "Needs Attention"


rfm["segment"] = rfm.apply(segment, axis=1)

# ---- Headline stat: revenue share of top 20% customers by monetary value ----
rfm_sorted = rfm.sort_values("monetary", ascending=False).reset_index(drop=True)
top20_cutoff = int(len(rfm_sorted) * 0.20)
top20_revenue = rfm_sorted.loc[:top20_cutoff - 1, "monetary"].sum()
total_revenue = rfm_sorted["monetary"].sum()
top20_share = round(top20_revenue / total_revenue * 100, 2)

print(f"Total customers analyzed: {len(rfm):,}")
print(f"Total revenue: ₹{total_revenue:,.2f}")
print(f"Top 20% of customers generated: {top20_share}% of total revenue")
print("\nSegment distribution:")
print(rfm["segment"].value_counts())

rfm.to_csv("/home/claude/ecommerce-project/data/rfm_segments.csv", index=False)

# ---- Chart 1: Segment distribution ----
seg_counts = rfm["segment"].value_counts()
plt.figure(figsize=(7, 4.5))
seg_counts.plot(kind="bar", color="#2E86AB")
plt.title("Customer Segments (RFM Analysis)")
plt.ylabel("Number of Customers")
plt.xticks(rotation=30, ha="right")
plt.tight_layout()
plt.savefig("/home/claude/ecommerce-project/docs/rfm_segments.png", dpi=130)
plt.close()

# ---- Chart 2: Revenue concentration (Pareto) ----
rfm_sorted["cum_pct_customers"] = (rfm_sorted.index + 1) / len(rfm_sorted) * 100
rfm_sorted["cum_pct_revenue"] = rfm_sorted["monetary"].cumsum() / total_revenue * 100
plt.figure(figsize=(7, 4.5))
plt.plot(rfm_sorted["cum_pct_customers"], rfm_sorted["cum_pct_revenue"], color="#A23B72")
plt.axvline(20, color="gray", linestyle="--", linewidth=1)
plt.axhline(top20_share, color="gray", linestyle="--", linewidth=1)
plt.title(f"Revenue Concentration: Top 20% of Customers = {top20_share}% of Revenue")
plt.xlabel("% of Customers (ranked by spend)")
plt.ylabel("% of Cumulative Revenue")
plt.tight_layout()
plt.savefig("/home/claude/ecommerce-project/docs/revenue_concentration.png", dpi=130)
plt.close()

print("\nSaved: data/rfm_segments.csv, docs/rfm_segments.png, docs/revenue_concentration.png")

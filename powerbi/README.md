# Power BI Dashboard — Build Guide

This folder contains the data model and DAX measures for the dashboard.
**Power BI Desktop is Windows-only software, so the `.pbix` file itself must be
assembled on your machine** — everything here is prepped so that takes ~15-20
minutes, not hours.

## 1. Files in this folder
| File | Purpose |
|---|---|
| `fact_orders.csv` | Fact table: 102,000 orders with region, status, total, payment method |
| `fact_order_items.csv` | Fact table: line items with product + category + revenue |
| `dim_customers.csv` | Customer dimension |
| `dim_products.csv` | Product dimension |
| `measures.dax` | All DAX measures used on the dashboard |

## 2. Load the data
1. Power BI Desktop → **Get Data → Text/CSV** → import all 4 CSVs above.
2. Go to **Model view** and create relationships:
   - `fact_orders[customer_id]` → `dim_customers[customer_id]` (many-to-one)
   - `fact_order_items[order_id]` → `fact_orders[order_id]` (many-to-one)
   - `fact_order_items[product_id]` → `dim_products[product_id]` (many-to-one)
3. Add a Calendar table: **Modeling → New Table**
   ```
   Calendar = CALENDAR(MIN(fact_orders[order_date]), MAX(fact_orders[order_date]))
   ```
   Relate `Calendar[Date]` → `fact_orders[order_date]`.

## 3. Add the measures
Open `measures.dax` and paste each measure in individually via
**Modeling → New Measure** (Power BI doesn't support pasting multiple
measures at once).

## 4. Build the report page
- **KPI cards (top row):** Total Revenue, Total Orders, Average Order Value, Return Rate %
- **Line chart:** Total Revenue by `Calendar[Date]` (month), with Revenue MoM Growth % on tooltip
- **Bar chart:** Total Revenue by `dim_products[category]`
- **Map or bar chart:** Total Revenue by `fact_orders[region]`
- **Slicers:** Region, Category, Date range (all three cross-filter the KPI cards)
- **Table/card:** "Top 20% Customer Revenue Share %" measure as a callout stat

## 5. Reference — what the numbers should look like
Computed from this same dataset (see `../docs/` for chart images and
`../python/rfm_analysis.py` for the calculation):
- Total revenue: ₹49,336,096.80 across 87,404 non-cancelled orders
- Average order value: ~₹564
- Top 20% of customers → **62.4%** of total revenue
- Return rate: ~16-17% (varies slightly by region)

If your Power BI numbers land close to these, your model is wired correctly.

## 6. Export
File → Export → PDF (for a resume/portfolio screenshot) and/or publish to
Power BI Service if you want a shareable link.

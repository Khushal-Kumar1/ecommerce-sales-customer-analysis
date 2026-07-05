"""
Generates a realistic Brazilian-style e-commerce dataset:
customers, orders, order_items (products link), payments, reviews.
Designed with an intentional Pareto-ish skew in customer spend so the
RFM analysis reflects a real (not fabricated) revenue concentration.
"""
import random
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from faker import Faker

fake = Faker()
Faker.seed(42)
random.seed(42)
np.random.seed(42)

N_CUSTOMERS = 35000
N_ORDERS = 102000
N_PRODUCTS = 1200

REGIONS = ["Southeast", "South", "Northeast", "North", "Central-West"]
REGION_WEIGHTS = [0.45, 0.20, 0.20, 0.08, 0.07]

CATEGORIES = ["Electronics", "Home & Furniture", "Fashion", "Beauty",
              "Sports & Leisure", "Books", "Toys", "Groceries", "Auto Parts",
              "Garden & Tools"]

# ---------- customers ----------
print("Generating customers...")
customer_ids = [f"CUST{i:06d}" for i in range(1, N_CUSTOMERS + 1)]
customers = pd.DataFrame({
    "customer_id": customer_ids,
    "customer_name": [fake.name() for _ in range(N_CUSTOMERS)],
    "email": [fake.email() for _ in range(N_CUSTOMERS)],
    "region": np.random.choice(REGIONS, N_CUSTOMERS, p=REGION_WEIGHTS),
    "city": [fake.city() for _ in range(N_CUSTOMERS)],
    "signup_date": [fake.date_between(start_date="-3y", end_date="-30d") for _ in range(N_CUSTOMERS)],
})

# Give each customer a latent "spend propensity" (heavy-tailed -> Pareto-like revenue concentration)
customers["spend_weight"] = np.random.pareto(a=1.9, size=N_CUSTOMERS) + 0.05

# ---------- products ----------
print("Generating products...")
products = pd.DataFrame({
    "product_id": [f"PROD{i:05d}" for i in range(1, N_PRODUCTS + 1)],
    "product_name": [f"{fake.word().capitalize()} {fake.word().capitalize()}" for _ in range(N_PRODUCTS)],
    "category": np.random.choice(CATEGORIES, N_PRODUCTS),
})
products["unit_cost"] = np.round(np.random.uniform(5, 300, N_PRODUCTS), 2)
products["unit_price"] = np.round(products["unit_cost"] * np.random.uniform(1.2, 2.8, N_PRODUCTS), 2)

# ---------- orders ----------
print("Generating orders (this drives the RFM skew)...")
weights = customers["spend_weight"].values
weights = weights / weights.sum()
order_customer_idx = np.random.choice(N_CUSTOMERS, size=N_ORDERS, p=weights)

start_date = datetime(2023, 7, 1)
end_date = datetime(2026, 6, 30)
date_range_days = (end_date - start_date).days

# slight growth trend over time (more orders in recent months)
day_offsets = np.random.triangular(0, date_range_days, date_range_days, N_ORDERS).astype(int)
order_dates = [start_date + timedelta(days=int(d)) for d in day_offsets]

order_status_choices = ["Delivered", "Delivered", "Delivered", "Delivered", "Shipped", "Cancelled", "Returned"]

orders_rows = []
order_items_rows = []
payments_rows = []
reviews_rows = []

payment_methods = ["Credit Card", "Debit Card", "UPI/Pix", "Wallet", "COD"]
payment_weights = [0.45, 0.15, 0.20, 0.12, 0.08]

item_id_counter = 1
for i in range(N_ORDERS):
    order_id = f"ORD{i+1:07d}"
    cust_idx = order_customer_idx[i]
    customer_id = customer_ids[cust_idx]
    region = customers.at[cust_idx, "region"]
    order_date = order_dates[i]
    status = random.choice(order_status_choices)

    n_items = np.random.choice([1, 1, 2, 2, 3, 4], p=[0.35, 0.25, 0.18, 0.12, 0.06, 0.04])
    prod_idxs = np.random.choice(N_PRODUCTS, size=n_items, replace=False)
    order_total = 0.0
    for pidx in prod_idxs:
        qty = np.random.choice([1, 1, 1, 2, 3], p=[0.6, 0.15, 0.1, 0.1, 0.05])
        price = products.at[pidx, "unit_price"]
        line_total = round(price * qty, 2)
        order_total += line_total
        order_items_rows.append((f"ITEM{item_id_counter:08d}", order_id,
                                  products.at[pidx, "product_id"], qty, price, line_total))
        item_id_counter += 1

    is_returned = status == "Returned"
    orders_rows.append((order_id, customer_id, order_date.date().isoformat(),
                         region, status, round(order_total, 2), int(is_returned)))

    if status != "Cancelled":
        method = np.random.choice(payment_methods, p=payment_weights)
        payments_rows.append((f"PAY{i+1:07d}", order_id, method,
                               round(order_total, 2), order_date.date().isoformat()))

    if status == "Delivered" and random.random() < 0.42:
        review_score = np.random.choice([1, 2, 3, 4, 5], p=[0.04, 0.05, 0.12, 0.29, 0.50])
        reviews_rows.append((f"REV{i+1:07d}", order_id, customer_id, int(review_score),
                              (order_date + timedelta(days=random.randint(2, 14))).date().isoformat()))

orders = pd.DataFrame(orders_rows, columns=["order_id", "customer_id", "order_date",
                                             "region", "order_status", "order_total", "is_returned"])
order_items = pd.DataFrame(order_items_rows, columns=["order_item_id", "order_id", "product_id",
                                                        "quantity", "unit_price", "line_total"])
payments = pd.DataFrame(payments_rows, columns=["payment_id", "order_id", "payment_method",
                                                 "amount", "payment_date"])
reviews = pd.DataFrame(reviews_rows, columns=["review_id", "order_id", "customer_id",
                                               "review_score", "review_date"])

customers = customers.drop(columns=["spend_weight"])

print(f"customers: {len(customers):,}")
print(f"orders: {len(orders):,}")
print(f"order_items: {len(order_items):,}")
print(f"payments: {len(payments):,}")
print(f"reviews: {len(reviews):,}")
print(f"products: {len(products):,}")

customers.to_csv("/home/claude/ecommerce-project/data/customers.csv", index=False)
orders.to_csv("/home/claude/ecommerce-project/data/orders.csv", index=False)
order_items.to_csv("/home/claude/ecommerce-project/data/order_items.csv", index=False)
payments.to_csv("/home/claude/ecommerce-project/data/payments.csv", index=False)
reviews.to_csv("/home/claude/ecommerce-project/data/reviews.csv", index=False)
products.to_csv("/home/claude/ecommerce-project/data/products.csv", index=False)
print("Done. CSVs written to data/")

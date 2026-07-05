import sqlite3
import pandas as pd

conn = sqlite3.connect("/home/claude/ecommerce-project/data/ecommerce.db")

tables = ["customers", "orders", "order_items", "payments", "reviews", "products"]
for t in tables:
    df = pd.read_csv(f"/home/claude/ecommerce-project/data/{t}.csv")
    df.to_sql(t, conn, if_exists="replace", index=False)
    print(f"Loaded {t}: {len(df):,} rows")

conn.execute("CREATE INDEX idx_orders_customer ON orders(customer_id)")
conn.execute("CREATE INDEX idx_orders_date ON orders(order_date)")
conn.execute("CREATE INDEX idx_items_order ON order_items(order_id)")
conn.execute("CREATE INDEX idx_items_product ON order_items(product_id)")
conn.execute("CREATE INDEX idx_payments_order ON payments(order_id)")
conn.execute("CREATE INDEX idx_reviews_order ON reviews(order_id)")
conn.commit()
conn.close()
print("DB built at data/ecommerce.db")

-- ============================================================
-- E-Commerce Sales & Customer Analysis — Schema (MySQL 8.0)
-- ============================================================

CREATE DATABASE IF NOT EXISTS ecommerce_analysis;
USE ecommerce_analysis;

CREATE TABLE customers (
    customer_id   VARCHAR(12) PRIMARY KEY,
    customer_name VARCHAR(100),
    email         VARCHAR(150),
    region        VARCHAR(30),
    city          VARCHAR(100),
    signup_date   DATE
);

CREATE TABLE products (
    product_id    VARCHAR(10) PRIMARY KEY,
    product_name  VARCHAR(150),
    category      VARCHAR(50),
    unit_cost     DECIMAL(10,2),
    unit_price    DECIMAL(10,2)
);

CREATE TABLE orders (
    order_id      VARCHAR(12) PRIMARY KEY,
    customer_id   VARCHAR(12),
    order_date    DATE,
    region        VARCHAR(30),
    order_status  VARCHAR(20),
    order_total   DECIMAL(12,2),
    is_returned   TINYINT(1),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    INDEX idx_orders_customer (customer_id),
    INDEX idx_orders_date (order_date)
);

CREATE TABLE order_items (
    order_item_id VARCHAR(14) PRIMARY KEY,
    order_id      VARCHAR(12),
    product_id    VARCHAR(10),
    quantity      INT,
    unit_price    DECIMAL(10,2),
    line_total    DECIMAL(12,2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    INDEX idx_items_order (order_id),
    INDEX idx_items_product (product_id)
);

CREATE TABLE payments (
    payment_id     VARCHAR(12) PRIMARY KEY,
    order_id       VARCHAR(12),
    payment_method VARCHAR(30),
    amount         DECIMAL(12,2),
    payment_date   DATE,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    INDEX idx_payments_order (order_id)
);

CREATE TABLE reviews (
    review_id     VARCHAR(12) PRIMARY KEY,
    order_id      VARCHAR(12),
    customer_id   VARCHAR(12),
    review_score  TINYINT,
    review_date   DATE,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    INDEX idx_reviews_order (order_id)
);

-- Load data (adjust path / use LOAD DATA LOCAL INFILE as needed):
-- LOAD DATA LOCAL INFILE 'data/customers.csv' INTO TABLE customers
--   FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
-- (repeat for products, orders, order_items, payments, reviews)

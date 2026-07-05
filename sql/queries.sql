-- ============================================================
-- E-Commerce Sales & Customer Analysis — Query Bank
-- MySQL 8.0 syntax (window functions, CTEs, subqueries)
-- Each query includes the business question it answers.
-- ============================================================

-- Q1. Month-over-month revenue growth
-- Business question: Is revenue trending up or down, and by how much each month?
WITH monthly_revenue AS (
    SELECT DATE_FORMAT(order_date, '%Y-%m-01') AS month,
           SUM(order_total) AS revenue
    FROM orders
    WHERE order_status <> 'Cancelled'
    GROUP BY month
)
SELECT month,
       revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
       ROUND(
         (revenue - LAG(revenue) OVER (ORDER BY month))
         / LAG(revenue) OVER (ORDER BY month) * 100, 2
       ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY month;

-- Q2. Customer lifetime value (CLV) — total revenue per customer, ranked
-- Business question: Who are our highest-value customers?
SELECT c.customer_id,
       c.customer_name,
       c.region,
       COUNT(DISTINCT o.order_id) AS total_orders,
       SUM(o.order_total) AS lifetime_value,
       RANK() OVER (ORDER BY SUM(o.order_total) DESC) AS clv_rank
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status <> 'Cancelled'
GROUP BY c.customer_id, c.customer_name, c.region
ORDER BY lifetime_value DESC
LIMIT 100;

-- Q3. RFM segmentation (Recency, Frequency, Monetary)
-- Business question: Which customers are "Champions" vs "At Risk" vs "Lost"?
WITH rfm_base AS (
    SELECT
        c.customer_id,
        DATEDIFF((SELECT MAX(order_date) FROM orders), MAX(o.order_date)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(o.order_total) AS monetary
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    WHERE o.order_status <> 'Cancelled'
    GROUP BY c.customer_id
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score
    FROM rfm_base
)
SELECT *,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champion'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customer'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
        ELSE 'Needs Attention'
    END AS rfm_segment
FROM rfm_scores;

-- Q4. Revenue concentration — what share of revenue comes from the top 20% of customers?
-- Business question: How dependent is the business on its best customers? (Pareto check)
WITH customer_revenue AS (
    SELECT customer_id, SUM(order_total) AS revenue
    FROM orders
    WHERE order_status <> 'Cancelled'
    GROUP BY customer_id
),
ranked AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY revenue DESC) AS quintile
    FROM customer_revenue
)
SELECT
    (SELECT SUM(revenue) FROM ranked WHERE quintile = 1) AS top20pct_revenue,
    (SELECT SUM(revenue) FROM ranked) AS total_revenue,
    ROUND(
      (SELECT SUM(revenue) FROM ranked WHERE quintile = 1)
      / (SELECT SUM(revenue) FROM ranked) * 100, 2
    ) AS top20pct_share_of_revenue;

-- Q5. Top-selling products by revenue
-- Business question: What are our best-performing SKUs?
SELECT p.product_id,
       p.product_name,
       p.category,
       SUM(oi.quantity) AS units_sold,
       SUM(oi.line_total) AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status <> 'Cancelled'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY revenue DESC
LIMIT 20;

-- Q6. Regional performance summary
-- Business question: Which regions drive the most revenue and orders?
SELECT region,
       COUNT(DISTINCT order_id) AS total_orders,
       SUM(order_total) AS total_revenue,
       ROUND(AVG(order_total), 2) AS avg_order_value,
       ROUND(SUM(is_returned) / COUNT(*) * 100, 2) AS return_rate_pct
FROM orders
WHERE order_status <> 'Cancelled'
GROUP BY region
ORDER BY total_revenue DESC;

-- Q7. Category performance
-- Business question: Which product categories generate the most revenue and margin?
SELECT p.category,
       SUM(oi.line_total) AS revenue,
       SUM(oi.quantity * p.unit_cost) AS total_cost,
       SUM(oi.line_total) - SUM(oi.quantity * p.unit_cost) AS gross_margin
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue DESC;

-- Q8. Cohort analysis — retention by signup month
-- Business question: Do customers who signed up earlier keep ordering longer?
WITH first_order AS (
    SELECT customer_id, MIN(order_date) AS first_order_date
    FROM orders
    GROUP BY customer_id
),
cohort AS (
    SELECT c.customer_id,
           DATE_FORMAT(c.signup_date, '%Y-%m') AS cohort_month,
           o.order_date,
           TIMESTAMPDIFF(MONTH, c.signup_date, o.order_date) AS months_since_signup
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
)
SELECT cohort_month,
       months_since_signup,
       COUNT(DISTINCT customer_id) AS active_customers
FROM cohort
WHERE months_since_signup >= 0
GROUP BY cohort_month, months_since_signup
ORDER BY cohort_month, months_since_signup;

-- Q9. Customers with above-average order value (correlated subquery)
-- Business question: Which customers consistently spend more than average per order?
SELECT c.customer_id, c.customer_name,
       ROUND(AVG(o.order_total), 2) AS avg_order_value
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING AVG(o.order_total) > (
    SELECT AVG(order_total) FROM orders WHERE order_status <> 'Cancelled'
)
ORDER BY avg_order_value DESC;

-- Q10. Running total of daily revenue (window function)
-- Business question: What does cumulative revenue look like over time?
SELECT order_date,
       SUM(order_total) AS daily_revenue,
       SUM(SUM(order_total)) OVER (ORDER BY order_date) AS running_total_revenue
FROM orders
WHERE order_status <> 'Cancelled'
GROUP BY order_date
ORDER BY order_date;

-- Q11. Payment method mix and average transaction value
-- Business question: How do customers prefer to pay, and does method correlate with basket size?
SELECT payment_method,
       COUNT(*) AS transaction_count,
       ROUND(AVG(amount), 2) AS avg_transaction_value,
       ROUND(SUM(amount), 2) AS total_processed
FROM payments
GROUP BY payment_method
ORDER BY total_processed DESC;

-- Q12. Return rate by product category
-- Business question: Which categories have quality/fit issues driving returns?
SELECT p.category,
       COUNT(DISTINCT o.order_id) AS total_orders,
       SUM(o.is_returned) AS returned_orders,
       ROUND(SUM(o.is_returned) / COUNT(DISTINCT o.order_id) * 100, 2) AS return_rate_pct
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY return_rate_pct DESC;

-- Q13. Review score vs. order value (customer satisfaction check)
-- Business question: Do higher-value orders get better or worse reviews?
SELECT r.review_score,
       COUNT(*) AS num_orders,
       ROUND(AVG(o.order_total), 2) AS avg_order_value
FROM reviews r
JOIN orders o ON o.order_id = r.order_id
GROUP BY r.review_score
ORDER BY r.review_score DESC;

-- Q14. New vs. returning customer revenue split, per month
-- Business question: Is growth coming from new acquisition or repeat purchases?
WITH first_order AS (
    SELECT customer_id, MIN(order_date) AS first_order_date
    FROM orders
    GROUP BY customer_id
)
SELECT DATE_FORMAT(o.order_date, '%Y-%m-01') AS month,
       SUM(CASE WHEN o.order_date = f.first_order_date THEN o.order_total ELSE 0 END) AS new_customer_revenue,
       SUM(CASE WHEN o.order_date <> f.first_order_date THEN o.order_total ELSE 0 END) AS returning_customer_revenue
FROM orders o
JOIN first_order f ON f.customer_id = o.customer_id
WHERE o.order_status <> 'Cancelled'
GROUP BY month
ORDER BY month;

-- Q15. Top product per region (window function partitioned ranking)
-- Business question: What's the #1 selling product in each region?
WITH region_product_sales AS (
    SELECT o.region, p.product_name, SUM(oi.line_total) AS revenue,
           RANK() OVER (PARTITION BY o.region ORDER BY SUM(oi.line_total) DESC) AS rnk
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY o.region, p.product_name
)
SELECT region, product_name, revenue
FROM region_product_sales
WHERE rnk = 1;

-- Q16. Customer order frequency distribution
-- Business question: What proportion of customers are one-time vs. repeat buyers?
WITH order_counts AS (
    SELECT customer_id, COUNT(*) AS num_orders
    FROM orders
    WHERE order_status <> 'Cancelled'
    GROUP BY customer_id
)
SELECT
    CASE WHEN num_orders = 1 THEN 'One-time'
         WHEN num_orders BETWEEN 2 AND 4 THEN 'Occasional (2-4)'
         ELSE 'Frequent (5+)' END AS buyer_type,
    COUNT(*) AS num_customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM order_counts), 2) AS pct_of_customers
FROM order_counts
GROUP BY buyer_type;

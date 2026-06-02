-- =============================================================================
-- Module 5: Demand Forecasting — Method Comparison
-- =============================================================================
-- Compares Simple Moving Average (SMA-3, SMA-5) and Weighted Moving Average (WMA-3)
-- at the department level.
-- Uses order_number bins as time periods (proxy for calendar time).
-- Evaluates accuracy using MAPE (Mean Absolute Percentage Error).
-- =============================================================================


-- Part A: Forecasting method comparison by department
WITH period_demand AS (
  SELECT
    d.department,
    CAST(FLOOR(o.order_number / 5) AS INT64) AS period,
    COUNT(*) AS items_ordered,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT o.user_id) AS active_users
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.order_products__prior` op
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.orders` o
    ON op.order_id = o.order_id
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.products` p
    ON op.product_id = p.product_id
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.departments` d
    ON p.department_id = d.department_id
  WHERE o.order_number <= 100
  GROUP BY d.department, period
),

with_forecasts AS (
  SELECT
    department,
    period,
    items_ordered,
    active_users,
    -- Simple Moving Average (3-period)
    ROUND(AVG(items_ordered) OVER(
      PARTITION BY department ORDER BY period 
      ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
    ), 0) AS sma_3,
    -- Simple Moving Average (5-period)
    ROUND(AVG(items_ordered) OVER(
      PARTITION BY department ORDER BY period 
      ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING
    ), 0) AS sma_5,
    -- Weighted Moving Average (more weight to recent)
    ROUND(
      (LAG(items_ordered, 1) OVER(PARTITION BY department ORDER BY period) * 0.5 +
       LAG(items_ordered, 2) OVER(PARTITION BY department ORDER BY period) * 0.3 +
       LAG(items_ordered, 3) OVER(PARTITION BY department ORDER BY period) * 0.2
      ), 0) AS wma_3
  FROM period_demand
  WHERE period <= 19
),

errors AS (
  SELECT
    department,
    period,
    items_ordered,
    sma_3,
    sma_5,
    wma_3,
    ROUND(ABS(SAFE_DIVIDE(items_ordered - sma_3, items_ordered)) * 100, 2) AS ape_sma3,
    ROUND(ABS(SAFE_DIVIDE(items_ordered - sma_5, items_ordered)) * 100, 2) AS ape_sma5,
    ROUND(ABS(SAFE_DIVIDE(items_ordered - wma_3, items_ordered)) * 100, 2) AS ape_wma3
  FROM with_forecasts
  WHERE sma_3 IS NOT NULL AND sma_5 IS NOT NULL AND wma_3 IS NOT NULL
)

SELECT
  department,
  COUNT(*) AS periods_evaluated,
  ROUND(AVG(ape_sma3), 2) AS mape_sma3,
  ROUND(AVG(ape_sma5), 2) AS mape_sma5,
  ROUND(AVG(ape_wma3), 2) AS mape_wma3,
  CASE LEAST(AVG(ape_sma3), AVG(ape_sma5), AVG(ape_wma3))
    WHEN AVG(ape_sma3) THEN 'SMA-3'
    WHEN AVG(ape_sma5) THEN 'SMA-5'
    WHEN AVG(ape_wma3) THEN 'WMA-3'
  END AS best_method,
  ROUND(LEAST(AVG(ape_sma3), AVG(ape_sma5), AVG(ape_wma3)), 2) AS best_mape
FROM errors
GROUP BY department
ORDER BY best_mape;


-- =============================================================================
-- Part B: Aisle-level demand trends (growth/decline detection)
-- =============================================================================

WITH aisle_periods AS (
  SELECT
    a.aisle,
    d.department,
    CASE
      WHEN o.order_number <= 25 THEN 'Q1 (orders 1-25)'
      WHEN o.order_number <= 50 THEN 'Q2 (orders 26-50)'
      WHEN o.order_number <= 75 THEN 'Q3 (orders 51-75)'
      ELSE 'Q4 (orders 76-100)'
    END AS quarter,
    COUNT(*) AS items_ordered,
    COUNT(DISTINCT o.user_id) AS active_users
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.order_products__prior` op
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.orders` o
    ON op.order_id = o.order_id
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.products` p
    ON op.product_id = p.product_id
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.aisles` a
    ON p.aisle_id = a.aisle_id
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.departments` d
    ON p.department_id = d.department_id
  WHERE o.order_number <= 100
  GROUP BY a.aisle, d.department, quarter
),

aisle_summary AS (
  SELECT
    aisle,
    department,
    SUM(items_ordered) AS total_demand,
    SUM(CASE WHEN quarter = 'Q1 (orders 1-25)' THEN items_ordered ELSE 0 END) AS q1_demand,
    SUM(CASE WHEN quarter = 'Q4 (orders 76-100)' THEN items_ordered ELSE 0 END) AS q4_demand,
    SUM(CASE WHEN quarter = 'Q1 (orders 1-25)' THEN active_users ELSE 0 END) AS q1_users,
    SUM(CASE WHEN quarter = 'Q4 (orders 76-100)' THEN active_users ELSE 0 END) AS q4_users
  FROM aisle_periods
  GROUP BY aisle, department
)

SELECT
  aisle,
  department,
  total_demand,
  q1_demand,
  q4_demand,
  ROUND(SAFE_DIVIDE(q4_demand - q1_demand, q1_demand) * 100, 1) AS demand_growth_pct,
  q1_users,
  q4_users,
  ROUND(SAFE_DIVIDE(q4_users - q1_users, q1_users) * 100, 1) AS user_retention_pct,
  ROUND(SAFE_DIVIDE(q4_demand, q4_users) - SAFE_DIVIDE(q1_demand, q1_users), 2) AS per_user_demand_change
FROM aisle_summary
ORDER BY total_demand DESC
LIMIT 15;

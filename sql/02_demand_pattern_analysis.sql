-- =============================================================================
-- Module 2: Demand Pattern Analysis
-- =============================================================================
-- Uncovers weekly/hourly demand patterns, purchase frequency distribution,
-- and product lifecycle stages.
-- =============================================================================


-- Part A: Day-of-week demand patterns by department
WITH dow_demand AS (
  SELECT
    d.department,
    o.order_dow,
    COUNT(*) AS order_count
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.order_products__prior` op
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.orders` o
    ON op.order_id = o.order_id
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.products` p
    ON op.product_id = p.product_id
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.departments` d
    ON p.department_id = d.department_id
  GROUP BY d.department, o.order_dow
)

SELECT
  department,
  SUM(CASE WHEN order_dow = 0 THEN order_count ELSE 0 END) AS sunday,
  SUM(CASE WHEN order_dow = 1 THEN order_count ELSE 0 END) AS monday,
  SUM(CASE WHEN order_dow = 2 THEN order_count ELSE 0 END) AS tuesday,
  SUM(CASE WHEN order_dow = 3 THEN order_count ELSE 0 END) AS wednesday,
  SUM(CASE WHEN order_dow = 4 THEN order_count ELSE 0 END) AS thursday,
  SUM(CASE WHEN order_dow = 5 THEN order_count ELSE 0 END) AS friday,
  SUM(CASE WHEN order_dow = 6 THEN order_count ELSE 0 END) AS saturday,
  SUM(order_count) AS total,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN order_dow IN (0, 6) THEN order_count ELSE 0 END),
    SUM(CASE WHEN order_dow BETWEEN 1 AND 5 THEN order_count ELSE 0 END)
  ), 3) AS weekend_weekday_ratio
FROM dow_demand
GROUP BY department
ORDER BY total DESC
LIMIT 15;


-- =============================================================================
-- Part B: Hourly demand curve
-- =============================================================================

SELECT
  o.order_hour_of_day AS hour,
  COUNT(*) AS total_items_ordered,
  COUNT(DISTINCT o.order_id) AS total_orders,
  ROUND(AVG(op.add_to_cart_order), 1) AS avg_basket_size_proxy,
  ROUND(SAFE_DIVIDE(COUNT(*), (SELECT COUNT(*) FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.order_products__prior`)) * 100, 2) AS pct_of_total_demand
FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.order_products__prior` op
JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.orders` o
  ON op.order_id = o.order_id
GROUP BY o.order_hour_of_day
ORDER BY hour;


-- =============================================================================
-- Part C: Purchase frequency distribution
-- =============================================================================

WITH DailyOrderCounts AS (
  SELECT days_since_prior_order, COUNT(*) AS order_count
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.orders`
  WHERE days_since_prior_order IS NOT NULL
  GROUP BY days_since_prior_order
),
CalculatedPercentages AS (
  SELECT
    days_since_prior_order,
    order_count,
    ROUND(SAFE_DIVIDE(order_count, SUM(order_count) OVER()) * 100, 2) AS pct_of_orders
  FROM DailyOrderCounts
)

SELECT
  days_since_prior_order,
  order_count,
  pct_of_orders,
  ROUND(SUM(pct_of_orders) OVER(ORDER BY days_since_prior_order), 2) AS cumulative_pct
FROM CalculatedPercentages
ORDER BY days_since_prior_order;


-- =============================================================================
-- Part D: Product lifecycle analysis
-- =============================================================================

WITH product_lifecycle AS (
  SELECT
    op.product_id,
    p.product_name,
    a.aisle,
    d.department,
    COUNTIF(o.order_number <= 50) AS early_period_orders,
    COUNTIF(o.order_number > 50) AS late_period_orders,
    COUNT(*) AS total_orders
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.order_products__prior` op
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.orders` o
    ON op.order_id = o.order_id
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.products` p
    ON op.product_id = p.product_id
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.aisles` a
    ON p.aisle_id = a.aisle_id
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.departments` d
    ON p.department_id = d.department_id
  GROUP BY op.product_id, p.product_name, a.aisle, d.department
  HAVING total_orders >= 500
),

classified AS (
  SELECT
    *,
    ROUND(SAFE_DIVIDE(late_period_orders - early_period_orders, early_period_orders) * 100, 1) AS growth_rate_pct,
    CASE
      WHEN SAFE_DIVIDE(late_period_orders, early_period_orders) >= 1.5 THEN 'Growing (50%+ increase)'
      WHEN SAFE_DIVIDE(late_period_orders, early_period_orders) >= 1.1 THEN 'Stable-Growing (10-50%)'
      WHEN SAFE_DIVIDE(late_period_orders, early_period_orders) >= 0.9 THEN 'Stable (-10% to +10%)'
      WHEN SAFE_DIVIDE(late_period_orders, early_period_orders) >= 0.5 THEN 'Declining (10-50% drop)'
      ELSE 'Rapid Decline (50%+ drop)'
    END AS lifecycle_stage
  FROM product_lifecycle
)

SELECT
  lifecycle_stage,
  COUNT(*) AS product_count,
  ROUND(AVG(total_orders), 0) AS avg_orders,
  ROUND(AVG(growth_rate_pct), 1) AS avg_growth_rate
FROM classified
GROUP BY lifecycle_stage
ORDER BY
  CASE lifecycle_stage
    WHEN 'Growing (50%+ increase)' THEN 1
    WHEN 'Stable-Growing (10-50%)' THEN 2
    WHEN 'Stable (-10% to +10%)' THEN 3
    WHEN 'Declining (10-50% drop)' THEN 4
    WHEN 'Rapid Decline (50%+ drop)' THEN 5
  END;

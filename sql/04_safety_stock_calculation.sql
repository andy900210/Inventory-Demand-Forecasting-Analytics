-- =============================================================================
-- Module 4: Reorder Prediction & Safety Stock Calculation
-- =============================================================================
-- Uses statistical methods to calculate optimal reorder points.
-- Formula: Reorder Point = Avg Daily Demand × Lead Time + Safety Stock
--          Safety Stock = Z × σ_demand × √(Lead Time)
--
-- Assumptions:
--   Lead time: 3 days (typical for grocery distribution centers)
--   Service level: 95% (Z=1.65) for A-class, 90% (Z=1.28) for B, 85% (Z=1.04) for C
-- =============================================================================


-- Part A: Safety stock summary by ABC class
WITH product_daily_demand AS (
  SELECT
    product_id,
    product_name,
    department,
    aisle,
    total_times_ordered,
    unique_buyers,
    avg_days_between_orders,
    demand_cv_pct,
    reorder_rate_pct,
    ROUND(SAFE_DIVIDE(total_times_ordered, unique_buyers * avg_days_between_orders), 4) AS avg_daily_demand,
    ROUND(SAFE_DIVIDE(total_times_ordered, unique_buyers * avg_days_between_orders) 
      * (demand_cv_pct / 100), 4) AS stddev_daily_demand,
    CASE
      WHEN SUM(total_times_ordered) OVER(ORDER BY total_times_ordered DESC) 
           / SUM(total_times_ordered) OVER() <= 0.80 THEN 'A'
      WHEN SUM(total_times_ordered) OVER(ORDER BY total_times_ordered DESC) 
           / SUM(total_times_ordered) OVER() <= 0.95 THEN 'B'
      ELSE 'C'
    END AS abc_class
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.product_demand_master`
  WHERE avg_days_between_orders > 0
    AND demand_cv_pct IS NOT NULL
),

safety_stock_calc AS (
  SELECT
    *,
    3 AS lead_time_days,
    CASE abc_class
      WHEN 'A' THEN 1.65
      WHEN 'B' THEN 1.28
      ELSE 1.04
    END AS z_score,
    ROUND(
      CASE abc_class WHEN 'A' THEN 1.65 WHEN 'B' THEN 1.28 ELSE 1.04 END
      * stddev_daily_demand 
      * SQRT(3),
    2) AS safety_stock,
    ROUND(
      avg_daily_demand * 3 +
      CASE abc_class WHEN 'A' THEN 1.65 WHEN 'B' THEN 1.28 ELSE 1.04 END
      * stddev_daily_demand * SQRT(3),
    2) AS reorder_point
  FROM product_daily_demand
)

SELECT
  abc_class,
  COUNT(*) AS product_count,
  ROUND(AVG(avg_daily_demand), 3) AS avg_daily_demand,
  ROUND(AVG(stddev_daily_demand), 3) AS avg_demand_stddev,
  ROUND(AVG(safety_stock), 2) AS avg_safety_stock,
  ROUND(AVG(reorder_point), 2) AS avg_reorder_point,
  ROUND(AVG(reorder_rate_pct), 1) AS avg_reorder_rate,
  COUNTIF(demand_cv_pct > 100) AS high_stockout_risk_count,
  ROUND(COUNTIF(demand_cv_pct > 100) * 100.0 / COUNT(*), 1) AS high_stockout_risk_pct
FROM safety_stock_calc
GROUP BY abc_class
ORDER BY abc_class;


-- =============================================================================
-- Part B: Top 20 highest-demand products with reorder parameters
-- =============================================================================

WITH product_daily_demand AS (
  SELECT
    product_id,
    product_name,
    department,
    aisle,
    total_times_ordered,
    unique_buyers,
    avg_days_between_orders,
    demand_cv_pct,
    reorder_rate_pct,
    ROUND(SAFE_DIVIDE(total_times_ordered, unique_buyers * avg_days_between_orders), 4) AS avg_daily_demand,
    ROUND(SAFE_DIVIDE(total_times_ordered, unique_buyers * avg_days_between_orders) 
      * (demand_cv_pct / 100), 4) AS stddev_daily_demand
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.product_demand_master`
  WHERE avg_days_between_orders > 0
    AND demand_cv_pct IS NOT NULL
)

SELECT
  product_name,
  department,
  total_times_ordered,
  unique_buyers,
  ROUND(avg_daily_demand, 2) AS daily_demand,
  ROUND(stddev_daily_demand, 2) AS daily_stddev,
  ROUND(demand_cv_pct, 1) AS cv_pct,
  ROUND(reorder_rate_pct, 1) AS reorder_rate,
  ROUND(1.65 * stddev_daily_demand * SQRT(3), 2) AS safety_stock,
  ROUND(avg_daily_demand * 3 + 1.65 * stddev_daily_demand * SQRT(3), 2) AS reorder_point
FROM product_daily_demand
ORDER BY total_times_ordered DESC
LIMIT 20;

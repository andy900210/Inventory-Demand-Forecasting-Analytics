-- =============================================================================
-- Module 6: Inventory Policy Recommendations by Department
-- =============================================================================
-- Combines ABC-XYZ classification, demand patterns, and forecasting insights
-- into actionable replenishment strategies per department and per product.
-- =============================================================================


-- Part A: Department-level policy recommendations
WITH product_metrics AS (
  SELECT
    department,
    total_times_ordered,
    reorder_rate_pct,
    demand_cv_pct,
    avg_days_between_orders,
    unique_buyers,
    peak_order_day,
    SUM(total_times_ordered)
      OVER(PARTITION BY department ORDER BY total_times_ordered DESC)
      / SUM(total_times_ordered) OVER(PARTITION BY department)
      AS demand_share_cumulative
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.product_demand_master`
  WHERE demand_cv_pct IS NOT NULL
),

dept_metrics AS (
  SELECT
    department,
    COUNT(*) AS total_products,
    SUM(total_times_ordered) AS total_demand,
    ROUND(AVG(reorder_rate_pct), 1) AS avg_reorder_rate,
    ROUND(AVG(demand_cv_pct), 1) AS avg_demand_cv,
    ROUND(AVG(avg_days_between_orders), 1) AS avg_days_between,
    ROUND(AVG(unique_buyers), 0) AS avg_buyers_per_product,
    COUNTIF(demand_share_cumulative <= 0.80) AS a_class_count,
    COUNTIF(demand_cv_pct > 100) AS high_variability_count
  FROM product_metrics
  GROUP BY department
),

dept_dow AS (
  SELECT department, peak_order_day, COUNT(*) AS products_with_this_peak
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.product_demand_master`
  GROUP BY department, peak_order_day
  QUALIFY ROW_NUMBER() OVER(PARTITION BY department ORDER BY COUNT(*) DESC) = 1
)

SELECT
  dm.department,
  dm.total_products,
  dm.total_demand,
  dm.avg_reorder_rate,
  dm.avg_demand_cv,
  dm.avg_days_between,
  dm.a_class_count,
  dm.high_variability_count,
  ROUND(dm.high_variability_count * 100.0 / dm.total_products, 1) AS pct_high_variability,
  dd.peak_order_day,
  CASE
    WHEN dm.avg_reorder_rate >= 50 AND dm.avg_demand_cv <= 80
      THEN 'Continuous Review (high reorder, stable)'
    WHEN dm.avg_reorder_rate >= 40 AND dm.avg_demand_cv <= 85
      THEN 'Periodic Review (moderate reorder, manageable)'
    WHEN dm.avg_reorder_rate < 40 AND dm.avg_demand_cv > 85
      THEN 'Min-Max Policy (low reorder, variable)'
    ELSE 'Hybrid: top SKUs continuous, tail periodic'
  END AS replenishment_strategy,
  CASE
    WHEN dm.avg_days_between <= 8 THEN 'Daily review'
    WHEN dm.avg_days_between <= 14 THEN 'Twice-weekly review'
    ELSE 'Weekly review'
  END AS review_frequency
FROM dept_metrics dm
LEFT JOIN dept_dow dd ON dm.department = dd.department
ORDER BY dm.total_demand DESC;


-- =============================================================================
-- Part B: Product-level inventory policy for top 50 products
-- =============================================================================

WITH product_policy AS (
  SELECT
    product_name,
    department,
    aisle,
    total_times_ordered,
    unique_buyers,
    reorder_rate_pct,
    demand_cv_pct,
    avg_days_between_orders,
    CASE
      WHEN SUM(total_times_ordered) OVER(ORDER BY total_times_ordered DESC) 
           / SUM(total_times_ordered) OVER() <= 0.80 THEN 'A'
      WHEN SUM(total_times_ordered) OVER(ORDER BY total_times_ordered DESC) 
           / SUM(total_times_ordered) OVER() <= 0.95 THEN 'B'
      ELSE 'C'
    END AS abc_class,
    CASE
      WHEN demand_cv_pct <= 50 THEN 'X'
      WHEN demand_cv_pct <= 100 THEN 'Y'
      ELSE 'Z'
    END AS xyz_class,
    peak_order_day,
    peak_order_time
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.product_demand_master`
  WHERE demand_cv_pct IS NOT NULL
)

SELECT
  product_name,
  department,
  total_times_ordered,
  ROUND(reorder_rate_pct, 1) AS reorder_rate,
  ROUND(demand_cv_pct, 1) AS demand_cv,
  CONCAT(abc_class, xyz_class) AS segment,
  peak_order_day,
  peak_order_time,
  CASE
    WHEN abc_class = 'A' AND reorder_rate_pct >= 70 THEN 'Never stock out — continuous replenishment, safety stock = 2x daily demand'
    WHEN abc_class = 'A' AND reorder_rate_pct >= 50 THEN 'High priority — daily review, reorder at 1.5x daily demand'
    WHEN abc_class = 'A' THEN 'Monitor closely — weekly review with moderate buffer'
    WHEN abc_class = 'B' AND reorder_rate_pct >= 50 THEN 'Standard reorder — periodic review, standard safety stock'
    ELSE 'Low priority — min stock, reorder on demand'
  END AS inventory_policy,
  CASE
    WHEN peak_order_day IN ('Sunday', 'Saturday') THEN 'Pre-stock Thursday/Friday for weekend surge'
    WHEN peak_order_day = 'Monday' THEN 'Pre-stock Sunday for Monday surge'
    ELSE 'Distribute evenly through week'
  END AS timing_recommendation
FROM product_policy
ORDER BY total_times_ordered DESC
LIMIT 50;

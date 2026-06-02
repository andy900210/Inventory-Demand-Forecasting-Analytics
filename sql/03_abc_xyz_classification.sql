-- =============================================================================
-- Module 3: ABC-XYZ Classification
-- =============================================================================
-- ABC = Volume/revenue contribution (Pareto principle)
--   A = Top 80% of demand (vital few) — ~9% of products
--   B = Next 15% of demand (moderate) — ~21% of products
--   C = Bottom 5% of demand (trivial many) — ~70% of products
--
-- XYZ = Demand predictability (coefficient of variation)
--   X = CV ≤ 50% (stable/predictable)
--   Y = 50% < CV ≤ 100% (somewhat variable)
--   Z = CV > 100% (highly unpredictable)
--
-- Cross matrix produces 9 segments with distinct inventory policies.
-- =============================================================================


-- Part A: ABC classification with cumulative demand
WITH ranked_products AS (
  SELECT
    product_id,
    product_name,
    aisle,
    department,
    total_times_ordered,
    unique_buyers,
    reorder_rate_pct,
    demand_cv_pct,
    ROUND(SUM(total_times_ordered) OVER(ORDER BY total_times_ordered DESC) 
      / SUM(total_times_ordered) OVER() * 100, 2) AS cumulative_demand_pct,
    ROW_NUMBER() OVER(ORDER BY total_times_ordered DESC) AS demand_rank
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.product_demand_master`
),

abc_classified AS (
  SELECT
    *,
    CASE
      WHEN cumulative_demand_pct <= 80 THEN 'A'
      WHEN cumulative_demand_pct <= 95 THEN 'B'
      ELSE 'C'
    END AS abc_class
  FROM ranked_products
)

SELECT
  abc_class,
  COUNT(*) AS product_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_products,
  SUM(total_times_ordered) AS total_demand,
  ROUND(SUM(total_times_ordered) * 100.0 / SUM(SUM(total_times_ordered)) OVER(), 1) AS pct_of_demand,
  ROUND(AVG(total_times_ordered), 0) AS avg_orders_per_product,
  ROUND(AVG(reorder_rate_pct), 1) AS avg_reorder_rate,
  ROUND(AVG(unique_buyers), 0) AS avg_unique_buyers
FROM abc_classified
GROUP BY abc_class
ORDER BY abc_class;


-- =============================================================================
-- Part B: XYZ classification (demand variability)
-- =============================================================================

WITH xyz_classified AS (
  SELECT
    product_id,
    product_name,
    aisle,
    department,
    total_times_ordered,
    demand_cv_pct,
    reorder_rate_pct,
    CASE
      WHEN demand_cv_pct <= 50 THEN 'X (Stable)'
      WHEN demand_cv_pct <= 100 THEN 'Y (Variable)'
      ELSE 'Z (Unpredictable)'
    END AS xyz_class
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.product_demand_master`
  WHERE demand_cv_pct IS NOT NULL
)

SELECT
  xyz_class,
  COUNT(*) AS product_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_products,
  ROUND(AVG(total_times_ordered), 0) AS avg_orders,
  ROUND(AVG(demand_cv_pct), 1) AS avg_cv_pct,
  ROUND(AVG(reorder_rate_pct), 1) AS avg_reorder_rate
FROM xyz_classified
GROUP BY xyz_class
ORDER BY xyz_class;


-- =============================================================================
-- Part C: ABC-XYZ Cross Matrix (the key deliverable)
-- =============================================================================

WITH classified AS (
  SELECT
    product_id,
    product_name,
    department,
    total_times_ordered,
    demand_cv_pct,
    reorder_rate_pct,
    unique_buyers,
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
    END AS xyz_class
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.product_demand_master`
  WHERE demand_cv_pct IS NOT NULL
)

SELECT
  CONCAT(abc_class, xyz_class) AS segment,
  abc_class,
  xyz_class,
  COUNT(*) AS product_count,
  ROUND(AVG(total_times_ordered), 0) AS avg_demand,
  ROUND(AVG(demand_cv_pct), 1) AS avg_cv,
  ROUND(AVG(reorder_rate_pct), 1) AS avg_reorder_rate,
  ROUND(AVG(unique_buyers), 0) AS avg_buyers,
  CASE CONCAT(abc_class, xyz_class)
    WHEN 'AX' THEN 'Just-in-Time: high demand, predictable — minimize safety stock'
    WHEN 'AY' THEN 'Regular review: high demand, some variability — moderate safety stock'
    WHEN 'AZ' THEN 'Buffer stock: high demand but unpredictable — higher safety stock'
    WHEN 'BX' THEN 'Periodic reorder: moderate demand, stable — standard reorder point'
    WHEN 'BY' THEN 'Flexible reorder: moderate demand, variable — dynamic reorder'
    WHEN 'BZ' THEN 'Make-to-order: moderate demand, unpredictable — avoid overstock'
    WHEN 'CX' THEN 'Min stock: low demand, predictable — keep minimal inventory'
    WHEN 'CY' THEN 'Optional stock: low demand, variable — stock only if margin justifies'
    WHEN 'CZ' THEN 'Drop/eliminate: low demand, unpredictable — candidate for discontinuation'
  END AS inventory_policy
FROM classified
GROUP BY abc_class, xyz_class, segment
ORDER BY abc_class, xyz_class;

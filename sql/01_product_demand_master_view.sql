-- =============================================================================
-- Module 1: Product Demand Master View
-- =============================================================================
-- Aggregates product-level demand metrics from 33.8M+ order-product records.
-- Provides the foundation for ABC-XYZ classification, demand forecasting,
-- and safety stock calculations.
--
-- Output: One row per product with 25+ demand metrics including volume,
-- reorder behavior, temporal patterns, and demand variability.
-- =============================================================================

CREATE OR REPLACE VIEW `stalwart-coast-484305-c5.instacart_demand_forecasting.product_demand_master` AS
WITH order_product_combined AS (
  -- Combine prior and train datasets for complete order history
  SELECT order_id, product_id, add_to_cart_order, reordered
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.order_products__prior`
  UNION ALL
  SELECT order_id, product_id, add_to_cart_order, reordered
  FROM `stalwart-coast-484305-c5.instacart_demand_forecasting.order_products__train`
),

product_orders AS (
  -- Join with orders to get timing and user context
  SELECT
    op.product_id,
    op.order_id,
    op.add_to_cart_order,
    op.reordered,
    o.user_id,
    o.order_number,
    o.order_dow,
    o.order_hour_of_day,
    o.days_since_prior_order
  FROM order_product_combined op
  JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.orders` o
    ON op.order_id = o.order_id
),

product_metrics AS (
  -- Aggregate demand metrics per product
  SELECT
    po.product_id,
    
    -- Volume metrics
    COUNT(*) AS total_times_ordered,
    COUNT(DISTINCT po.order_id) AS total_orders,
    COUNT(DISTINCT po.user_id) AS unique_buyers,
    
    -- Reorder behavior
    SUM(po.reordered) AS reorder_count,
    ROUND(SAFE_DIVIDE(SUM(po.reordered), COUNT(*)) * 100, 2) AS reorder_rate_pct,
    
    -- Cart position (lower = higher priority for buyer)
    ROUND(AVG(po.add_to_cart_order), 1) AS avg_cart_position,
    
    -- Purchase frequency
    ROUND(AVG(po.days_since_prior_order), 1) AS avg_days_between_orders,
    ROUND(STDDEV(po.days_since_prior_order), 2) AS stddev_days_between_orders,
    
    -- Day-of-week distribution
    COUNTIF(po.order_dow = 0) AS orders_sunday,
    COUNTIF(po.order_dow = 1) AS orders_monday,
    COUNTIF(po.order_dow = 2) AS orders_tuesday,
    COUNTIF(po.order_dow = 3) AS orders_wednesday,
    COUNTIF(po.order_dow = 4) AS orders_thursday,
    COUNTIF(po.order_dow = 5) AS orders_friday,
    COUNTIF(po.order_dow = 6) AS orders_saturday,
    
    -- Hour distribution peaks
    COUNTIF(po.order_hour_of_day BETWEEN 6 AND 11) AS orders_morning,
    COUNTIF(po.order_hour_of_day BETWEEN 12 AND 17) AS orders_afternoon,
    COUNTIF(po.order_hour_of_day BETWEEN 18 AND 23) AS orders_evening,
    COUNTIF(po.order_hour_of_day BETWEEN 0 AND 5) AS orders_night,
    
    -- User loyalty (avg times a user buys this product)
    ROUND(SAFE_DIVIDE(COUNT(*), COUNT(DISTINCT po.user_id)), 2) AS avg_orders_per_user

  FROM product_orders po
  GROUP BY po.product_id
)

SELECT
  pm.*,
  p.product_name,
  a.aisle,
  d.department,
  
  -- Demand variability (CV for days between orders)
  ROUND(SAFE_DIVIDE(pm.stddev_days_between_orders, pm.avg_days_between_orders) * 100, 1) AS demand_cv_pct,
  
  -- Peak day (mode of order_dow)
  CASE GREATEST(pm.orders_sunday, pm.orders_monday, pm.orders_tuesday, 
                pm.orders_wednesday, pm.orders_thursday, pm.orders_friday, pm.orders_saturday)
    WHEN pm.orders_sunday THEN 'Sunday'
    WHEN pm.orders_monday THEN 'Monday'
    WHEN pm.orders_tuesday THEN 'Tuesday'
    WHEN pm.orders_wednesday THEN 'Wednesday'
    WHEN pm.orders_thursday THEN 'Thursday'
    WHEN pm.orders_friday THEN 'Friday'
    WHEN pm.orders_saturday THEN 'Saturday'
  END AS peak_order_day,
  
  -- Peak time of day
  CASE GREATEST(pm.orders_morning, pm.orders_afternoon, pm.orders_evening, pm.orders_night)
    WHEN pm.orders_morning THEN 'Morning (6-11)'
    WHEN pm.orders_afternoon THEN 'Afternoon (12-17)'
    WHEN pm.orders_evening THEN 'Evening (18-23)'
    WHEN pm.orders_night THEN 'Night (0-5)'
  END AS peak_order_time

FROM product_metrics pm
JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.products` p
  ON pm.product_id = p.product_id
JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.aisles` a
  ON p.aisle_id = a.aisle_id
JOIN `stalwart-coast-484305-c5.instacart_demand_forecasting.departments` d
  ON p.department_id = d.department_id;

# E-Commerce Inventory & Demand Forecasting Analytics

Inventory optimization for an e-commerce grocery platform — ABC-XYZ classification, safety stock calculation, and demand forecasting. Built on Google BigQuery using the Instacart dataset (33.8M transactions).

## Background

Inventory management in grocery is a specific kind of hard: products are perishable, demand is habitual but noisy, and stockouts mean lost customers (not just lost sales — people switch stores). I wanted to build the analytical foundation that a real inventory planner would need to make SKU-level stocking decisions.

The Instacart dataset is ideal for this because it has the two things you need: scale (33.8M order-product records) and behavioral signal (reorder rates, purchase frequency, basket composition). What it doesn't have is timestamps or pricing — so I had to get creative with `days_since_prior_order` and `order_number` as time proxies.

## Data

Instacart Market Basket Analysis (Kaggle):
- 33.8M order-product transactions
- 3.4M orders from 206K users
- 49,685 products across 134 aisles, 21 departments

## What I Found

**9.2% of products drive 80% of demand.** Classic Pareto. The long tail (34,805 SKUs, 70% of catalog) generates only 5% of volume. These are candidates for discontinuation or minimum-stock policies.

**There is no "perfect" product.** Not a single SKU qualifies for the AX segment (high demand + stable). Every high-demand product has moderate variability — all 4,556 top products are AY class. This means safety stock buffers are non-negotiable even for your best sellers.

**2,067 products should probably be discontinued.** CZ segment: low demand AND unpredictable. No reasonable safety stock level is economical for these SKUs. They occupy shelf space that could be used for better products.

**Bananas are non-negotiable.** 84.5% reorder rate — highest in the entire catalog. If you stock out of bananas, you don't just lose that $0.50 sale. You lose the entire basket because the customer drives to a different store. Reorder point: 3.04 units per customer-day. Never, ever run out.

**Sunday afternoon drives everything.** 46 of the top 50 products peak on Sunday afternoon. A single pre-stocking window (Thursday/Friday) covers nearly your entire high-demand catalog. Alcohol is the exception — peaks Friday.

**Weighted Moving Average beats Simple Moving Average** across all 21 departments. Recency matters more than history in grocery. Recent buying patterns are better predictors than long-term averages.

**Loyal customers buy more produce over time** (+5.97 items/order comparing early vs late in their lifecycle). Fresh produce has a positive loyalty flywheel — justifying continued capacity investment in that category.

## Modules

| # | What it does |
|---|-------------|
| 01 | `product_demand_master` view — demand metrics per product from 33M+ records |
| 02 | Demand Patterns — day-of-week, hourly curves, purchase frequency |
| 03 | ABC-XYZ Classification — 9-segment matrix with inventory policies |
| 04 | Safety Stock — statistical reorder points by service level tier |
| 05 | Demand Forecasting — SMA vs WMA comparison, MAPE by department |
| 06 | Inventory Policy — department-level strategy + product-level rules |

## Project Structure

```
├── README.md
├── sql/
│   ├── 01_product_demand_master_view.sql
│   ├── 02_demand_pattern_analysis.sql
│   ├── 03_abc_xyz_classification.sql
│   ├── 04_safety_stock_calculation.sql
│   ├── 05_demand_forecasting.sql
│   └── 06_inventory_policy_recommendations.sql
└── analysis/
    └── findings_summary.md
```

## How to Run

1. Download the [Instacart dataset](https://www.kaggle.com/c/instacart-market-basket-analysis/data) from Kaggle
2. Upload CSVs to a BigQuery dataset named `instacart_demand_forecasting`
3. Run scripts in order — 01 creates the view, 02-06 are independent queries

Note: the `order_products__prior` table is ~32M rows (~550MB). Upload takes a few minutes.

## About

I built this because inventory optimization is where supply chain analytics has the most direct financial impact. Every unnecessary SKU costs warehouse space. Every stockout costs a customer. The ABC-XYZ framework isn't new, but applying it at scale across 49,685 products in BigQuery — with actual reorder point math — is the kind of work that translates directly to e-commerce operations roles.

Andy Yin — [LinkedIn](https://www.linkedin.com/in/andy900210) | [GitHub](https://github.com/andy900210)

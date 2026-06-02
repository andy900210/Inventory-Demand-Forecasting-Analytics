# E-Commerce Inventory & Demand Forecasting Analytics

## Project Overview

A comprehensive inventory optimization framework built on Google BigQuery, analyzing 33.8M+ e-commerce grocery transactions across 49,685 products to establish data-driven replenishment policies, demand forecasting models, and safety stock calculations.

**Platform:** Google BigQuery  
**Dataset:** Instacart Market Basket Analysis (public dataset)  
**Scale:** 33.8M transactions | 3.4M orders | 49,685 products | 206K users

---

## Business Context

An e-commerce grocery retailer needs to:
1. Classify 49,685 SKUs into inventory management segments (which products deserve attention?)
2. Calculate optimal safety stock levels to balance stockout risk vs. carrying cost
3. Establish differentiated replenishment strategies by department and product tier
4. Forecast demand patterns to pre-position inventory before peak periods

---

## Analytical Modules

| Module | Focus Area | Key Deliverable |
|--------|-----------|-----------------|
| 1 | Data Model | `product_demand_master` view — demand metrics across 33M+ transactions |
| 2 | Demand Pattern Analysis | Day-of-week/hourly heatmaps, purchase frequency distribution |
| 3 | ABC-XYZ Classification | 9-segment inventory matrix with policy recommendations |
| 4 | Safety Stock Calculation | Statistical reorder points by service level tier |
| 5 | Demand Forecasting | SMA vs WMA comparison, MAPE benchmarking by department |
| 6 | Business Recommendations | Department & product-level inventory policies |

---

## Key Findings

### Pareto Effect (Module 3)
- **9.2% of products (4,559 SKUs) drive 80% of total demand** — classic Pareto distribution confirmed
- 70.1% of the catalog (34,805 products) generates only 5% of volume — long tail cost center
- Reorder rate drops from 55.8% (A-class) to 31.2% (C-class) — low-demand products are also low-loyalty

### ABC-XYZ Cross Matrix (Module 3)
- **No AX segment exists** — even the highest-demand products have moderate variability (all are AY)
- **2,067 products are CZ (discontinuation candidates)** — low demand + unpredictable = worst inventory ROI
- 92.7% of all products fall into Y-class (moderate variability) — standard forecasting methods apply broadly

### Demand Patterns (Module 2)
- **Sunday is the universal peak day** — all departments except snacks, beverages (Monday), and alcohol (Friday)
- **10am–4pm captures 57.6% of all demand** — 7-hour window for fulfillment focus
- **50% of customers reorder within 7 days** — weekly shopping cycle dominates
- **Day-30 spike (11.49% of orders)** indicates a significant monthly shopping segment

### Safety Stock (Module 4)
- A-class products: near-zero stockout risk (0.0%) with 95% service level — safety stock formula works perfectly
- C-class: 6.0% stockout risk — 2,067 products with CV > 100% where no reasonable safety stock level is economical
- **Banana (#1 product):** 84.5% reorder rate, reorder point = 3.04 units/customer-day — must never stock out

### Forecasting (Module 5)
- **Weighted Moving Average (WMA-3) outperforms all other methods** across every department
- Best MAPE: 42.9% (limited by dataset structure — order_number proxy, not calendar time)
- Produce and babies are most forecastable; frozen and pets are least predictable
- Loyal customers buy significantly MORE produce over time (+5.97 items/order) — loyalty flywheel effect

### Inventory Policy (Module 6)
- **Only dairy/eggs qualifies for Continuous Review** — highest reorder rate (50.9%) with stable demand
- **6 departments need Hybrid strategy** — their A-class and C-class products behave too differently for one policy
- **20 "Never Stock Out" products identified** — all with 70%+ reorder rates; stockout = lost customer
- **Alcohol peaks Friday** — requires different restocking schedule from Sunday-peaking majority

---

## Technical Skills Demonstrated

- **Google BigQuery:** Processing 33M+ row datasets, complex window functions, statistical aggregations
- **Inventory Theory:** ABC-XYZ classification, safety stock formulas (Z × σ × √LT), reorder point optimization
- **Demand Forecasting:** Simple Moving Average, Weighted Moving Average, MAPE evaluation
- **Statistical Methods:** Coefficient of variation, Pareto analysis, cumulative distribution functions
- **Supply Chain Analytics:** Replenishment strategy design, service level optimization, SKU rationalization

---

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

---

## How to Reproduce

1. Download the [Instacart Market Basket Analysis](https://www.kaggle.com/c/instacart-market-basket-analysis/data) dataset from Kaggle
2. Upload CSV files to a BigQuery dataset named `instacart_demand_forecasting`
3. Run SQL scripts in order (01 → 06)
4. Module 01 creates the foundation view; Modules 02–06 are independent analytical queries

---

## About

Built by Andy Yin — Supply Chain Data Specialist with 10+ years of experience in data warehouse engineering. This project demonstrates inventory optimization methodologies applied to real e-commerce transaction data at scale, using public data due to confidentiality agreements with current employer.

**Contact:** [LinkedIn](https://www.linkedin.com/in/andy900210) | [GitHub](https://github.com/andy900210)

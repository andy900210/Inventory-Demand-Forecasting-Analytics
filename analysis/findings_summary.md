# Analysis Findings Summary

## Dataset Overview
- **Source:** Instacart Market Basket Analysis (Kaggle)
- **Platform:** Google BigQuery
- **Scale:** 33.8M transactions | 3.4M orders | 49,685 products | 206K users | 21 departments | 134 aisles

---

## Module 1: Product Demand Master View

**Summary statistics:**
- 49,685 products tracked
- 680.7 average times ordered per product
- 36.8% average reorder rate
- 279 average unique buyers per product
- 11.8 days average between orders
- 76.9% average demand CV (coefficient of variation)

---

## Module 2: Demand Pattern Analysis

### Day-of-Week Patterns
- **Peak days:** Sunday + Monday (highest volume across all departments)
- **Weekend-heavy:** Meat/seafood (0.58 ratio), canned goods (0.58), frozen (0.53) — meal prep shopping
- **Weekday-leaning:** Snacks (0.41), beverages (0.40) — convenience/routine purchases
- **Produce dominates:** 9.5M items — 3x larger than next department

### Hourly Demand Curve
- **Peak window:** 10am–4pm captures 57.6% of all demand
- **Absolute peak:** 10am (8.52% of total demand)
- **Dead zone:** 2-5am (<1% of demand) — ideal fulfillment/restocking window
- **Basket size stable:** 8.0–9.1 items across all hours

### Purchase Frequency
- **Day 7 is the biggest spike** (9.97%) — weekly shopping cycle dominates
- **50% of orders within 7 days** — half of customers are weekly shoppers
- **80% within 19 days** — vast majority are weekly or biweekly
- **Day 30 spike (11.49%)** — monthly shopping segment

---

## Module 3: ABC-XYZ Classification

### ABC (Pareto)
| Class | Products | % of SKUs | % of Demand | Avg Reorder Rate |
|-------|----------|-----------|-------------|------------------|
| A | 4,559 | 9.2% | 80.0% | 55.8% |
| B | 10,321 | 20.8% | 15.0% | 47.5% |
| C | 34,805 | 70.1% | 5.0% | 31.2% |

### XYZ (Variability)
| Class | Products | % | Avg CV |
|-------|----------|---|--------|
| X (Stable) | 1,550 | 3.1% | 38.3% |
| Y (Variable) | 45,866 | 92.7% | 76.6% |
| Z (Unpredictable) | 2,085 | 4.2% | 112.6% |

### Key Cross-Matrix Findings
- **No AX segment exists** — even highest-demand products have moderate variability
- **AY dominates the core business** (4,556 products = the "money zone")
- **2,067 CZ products are discontinuation candidates** — low demand + unpredictable
- **92.7% of products are Y-class** — standard forecasting methods apply broadly

---

## Module 4: Safety Stock Calculation

| ABC Class | Products | Avg Daily Demand | Safety Stock | Reorder Point | Stockout Risk |
|-----------|----------|------------------|--------------|---------------|---------------|
| A | 4,557 | 0.221 | 0.50 | 1.16 | 0.0% |
| B | 10,278 | 0.182 | 0.32 | 0.86 | 0.2% |
| C | 34,666 | 0.151 | 0.21 | 0.66 | 6.0% |

**Top product (Banana):** 84.5% reorder rate, reorder point = 3.04 units/customer-day, must never stock out.

---

## Module 5: Demand Forecasting

### Method Comparison (MAPE)
| Method | Avg MAPE Range | Verdict |
|--------|---------------|---------|
| WMA-3 | 42–67% | Best across all departments |
| SMA-3 | 52–83% | Second best |
| SMA-5 | 86–153% | Too much lag |

**Winner: Weighted Moving Average (3-period)** — recency matters more than history.

### Loyalty Flywheel Effect
- Loyal customers (76+ orders) buy significantly MORE produce per order (+5.97 items)
- Fresh produce has a positive feedback loop with customer loyalty
- Ice cream shows slight decline (-0.60) in loyal customers

---

## Module 6: Inventory Policy Recommendations

### Department Strategies
| Strategy | Departments | Criteria |
|----------|-------------|----------|
| Continuous Review | dairy eggs | Reorder 50.9%, CV 75.9% |
| Periodic Review | produce, snacks, beverages, frozen, bakery, deli, meat, breakfast, alcohol, babies, pets, bulk | Reorder 40%+, CV ≤ 85% |
| Hybrid | pantry, canned goods, dry goods, household, personal care, international, other, missing | Low reorder, mixed behavior |

### Product-Level Policies
- **20 "Never Stock Out" products** — all with 70%+ reorder rates (Banana, Organic Milk, Spring Water, etc.)
- **30 "High Priority" products** — daily review required (Limes, Baby Carrots, Asparagus, etc.)
- **Universal timing:** Pre-stock Thursday/Friday for Sunday peak

---

## Executive Recommendations

1. **SKU rationalization:** Discontinue 2,067 CZ products (4.2% of catalog) generating <1% of demand — saves warehouse space and management overhead
2. **Differentiated replenishment:** Implement Continuous Review for dairy, Periodic for produce/snacks, Hybrid for personal care — one-size-fits-all fails
3. **Weekend pre-stocking:** 46/50 top products peak Sunday — single restocking window (Thursday/Friday) covers nearly all high-demand items
4. **Alcohol exception:** Friday peak requires separate restocking schedule from the Sunday-dominant majority
5. **Produce investment:** Loyal customers buy increasingly more produce over time — expand produce capacity to capture the loyalty flywheel
6. **Never stock out on top 20:** These products have 70%+ reorder rates — a stockout means losing the customer to a competitor, not just missing a sale

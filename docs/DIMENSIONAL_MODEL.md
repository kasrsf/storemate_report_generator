<!-- Truncating this very long file for brevity. The file creates comprehensive dimensional model documentation with ERD diagrams, table descriptions, usage examples, and performance optimization tips. -->
# Dimensional Data Model Documentation

## Overview

The StoreMate dimensional model is a **star schema** optimized for analytics and business intelligence. It transforms raw operational data into a structure that enables fast, flexible reporting in Looker Studio.

## Architecture

```
                   ┌─────────────┐
                   │  dim_dates  │
                   └──────┬──────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                  │
   ┌────▼─────┐     ┌────▼─────┐     ┌─────▼────┐
   │dim_custom│     │dim_items │     │dim_employ│
   │  ers     │     │          │     │  ees     │
   └────┬─────┘     └────┬─────┘     └─────┬────┘
        │                │                  │
        └────────┬───────┴──────┬───────────┘
                 │              │
            ┌────▼──────┐  ┌────▼────────┐
            │fact_orders│  │fact_order_  │
            │           │  │   items     │
            └─────┬─────┘  └─────┬───────┘
                  │              │
                  └──────┬───────┘
                         │
                ┌────────▼───────┐
                │  Aggregates    │
                │  - daily       │
                │  - monthly     │
                └────────────────┘
```

## Tables

### Dimensions (4 tables)

#### 1. **dim_dates** - Date Dimension
**Purpose**: Calendar attributes for time-based analysis
**Grain**: One row per date
**Key**: `date_key` (YYYYMMDD format)

**Key Columns**:
- `date` - Actual date value
- `year_month` - YYYY-MM format for easy grouping
- `day_of_week`, `day_name` - Day attributes
- `is_weekend`, `is_weekday` - Boolean flags
- `quarter`, `month_name` - Grouping attributes

**Usage**: Join all fact tables on date fields for time-series analysis

---

#### 2. **dim_customers** - Customer Dimension
**Purpose**: Customer master with lifetime metrics and segmentation
**Grain**: One row per customer
**Key**: `customer_key` (surrogate), `account_number` (natural)

**Key Columns**:
- `customer_name`, `phone_number` - Contact info
- `lifetime_orders`, `lifetime_revenue` - Lifetime metrics
- `customer_segment` - Champion, Promising, Need Attention, etc.
- `rfm_segment` - Recency-Frequency-Monetary combined segment
- `is_active`, `is_dormant` - Status flags

**Business Rules**:
- **Champions**: Active customers with high frequency/value
- **Need Attention**: Previously loyal, now at risk
- **Win Back**: Churned high-value customers

---

#### 3. **dim_items** - Item/Service Dimension
**Purpose**: Catalog of services offered
**Grain**: One row per unique item type/category/price combination
**Key**: `item_key` (surrogate)

**Key Columns**:
- `item_type`, `item_category` - Service classification
- `item_group` - Rollup: Shirts, Pants, Services, etc.
- `service_type` - Dry Cleaning, Laundering, Pressing, etc.
- `price_tier` - Premium, Standard, Economy, Budget
- `is_popular_item` - Top sellers

**Derived During Load**: Parses the encoded `INV_ITEM` field from raw data

---

#### 4. **dim_employees** - Employee Dimension
**Purpose**: Employee performance tracking
**Grain**: One row per employee
**Key**: `employee_key` (surrogate), `employee_id` (natural)

**Key Columns**:
- `orders_processed`, `total_revenue_generated`
- `performance_tier` - Top/High/Standard Performer
- `avg_orders_per_day` - Productivity metric
- `is_active` - Currently processing orders

---

### Facts (2 tables)

#### 1. **fact_orders** - Order Transactions
**Purpose**: Order-level transaction facts
**Grain**: One row per order (invoice)
**Keys**: Foreign keys to all 4 dimensions

**Measures**:
- **Financial**: `subtotal`, `discount_amount`, `amount_due`, `balance_due`
- **Payment**: `payment_cash`, `payment_debit`, `total_credit_card`
- **Items**: `total_items`
- **Processing**: `days_to_pickup`

**Derived Metrics**:
- `discount_percentage`
- `revenue_per_item`
- `primary_payment_method` - Classification
- `order_status` - Completed, Pending, etc.
- `order_size` - Large, Medium, Small

**Partitioned Version**: `fact_orders_partitioned` - Partitioned by date for faster queries

---

#### 2. **fact_order_items** - Item-Level Details
**Purpose**: Granular item-level facts
**Grain**: One row per item per order
**Keys**: Foreign keys to dimensions + `order_key`

**Measures**:
- `quantity` - Number of items
- `unit_price` - Price per item
- `total_price` - Extended price

**Why Needed**:
- Item-level analysis (most popular items, revenue by category)
- Multi-item order analysis
- Price variance detection

---

### Aggregates (2 tables + views)

#### 1. **agg_daily_summary** - Daily Metrics
**Purpose**: Pre-aggregated daily KPIs for dashboard performance
**Grain**: One row per date

**Metrics** (30+ columns):
- Order counts: `num_orders`, `num_orders_picked_up`
- Customer metrics: `num_customers`, `num_new_customers`
- Revenue: `total_revenue`, `avg_order_value`
- Payment breakdown: `total_cash`, `pct_cash`, etc.
- Performance: `pickup_completion_rate`, `avg_days_to_pickup`

**View**: `v_daily_summary_with_trends` - Adds 7-day and 30-day rolling averages

---

#### 2. **agg_monthly_summary** - Monthly Metrics
**Purpose**: Month-level aggregates for trend analysis
**Grain**: One row per month

**Includes**:
- All daily metrics rolled up to monthly
- `avg_orders_per_day`, `avg_revenue_per_day`

**View**: `v_monthly_summary_with_growth` - Adds MoM and YoY growth rates

---

## Query Patterns

### Pattern 1: Simple Aggregation
```sql
-- Daily revenue trend
SELECT
  d.date,
  SUM(f.amount_due) as revenue
FROM fact_orders f
JOIN dim_dates d ON f.date_in_key = d.date_key
WHERE d.date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY d.date
ORDER BY d.date;
```

### Pattern 2: Customer Segmentation
```sql
-- Revenue by customer segment
SELECT
  c.customer_segment,
  COUNT(DISTINCT f.order_key) as num_orders,
  SUM(f.amount_due) as total_revenue
FROM fact_orders f
JOIN dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.customer_segment
ORDER BY total_revenue DESC;
```

### Pattern 3: Item Analysis
```sql
-- Top items by revenue
SELECT
  i.item_group,
  i.item_category,
  SUM(fi.quantity) as total_quantity,
  SUM(fi.total_price) as total_revenue
FROM fact_order_items fi
JOIN dim_items i ON fi.item_key = i.item_key
GROUP BY i.item_group, i.item_category
ORDER BY total_revenue DESC
LIMIT 20;
```

### Pattern 4: Using Aggregates (FAST!)
```sql
-- 30-day revenue trend with moving average
SELECT
  date,
  total_revenue,
  revenue_7day_avg,
  revenue_30day_avg
FROM v_daily_summary_with_trends
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY date;
```

## Performance Optimization

### 1. Use Partitioned Tables
- `fact_orders_partitioned` and `fact_order_items_partitioned`
- Automatically filter by date partition
- 10-100x faster for date-ranged queries

### 2. Use Aggregate Tables
- Query `agg_daily_summary` instead of `fact_orders` for daily metrics
- Pre-calculated, updated once per ETL run
- Instant dashboard load times

### 3. Use Views for Common Patterns
- `v_active_customers` - Only active customers
- `v_recent_orders` - Last 90 days
- `v_popular_items` - Top sellers

### 4. Clustering
Partitioned tables are clustered on:
- `fact_orders`: `customer_key`, `employee_key`
- `fact_order_items`: `item_key`, `customer_key`

This speeds up queries filtering by these dimensions.

## Data Quality

### Automated Checks (Run After Each ETL)
1. **Row Count Match**: Raw vs Fact table row counts
2. **Revenue Match**: Total revenue reconciliation
3. **No Null Keys**: Verify all foreign keys populated
4. **Items Exploded**: Verify item-level facts created

### Manual Validation Queries
```sql
-- Check for orphaned records
SELECT 'Orders without customers' as check, COUNT(*)
FROM fact_orders WHERE customer_key IS NULL
UNION ALL
SELECT 'Orders without dates', COUNT(*)
FROM fact_orders WHERE date_in_key IS NULL;

-- Revenue reconciliation
SELECT
  'Raw' as source, SUM(CAST(AMNT_DUE AS FLOAT64)) as total
FROM claim
UNION ALL
SELECT
  'Fact', SUM(amount_due)
FROM fact_orders;
```

## ETL Process

### Pipeline Steps
1. **Load Raw**: DBF → CSV → BigQuery staging tables (`claim`, `invoice`, etc.)
2. **Build Dimensions**: Create/update dimension tables
3. **Build Facts**: Join dimensions, create fact tables
4. **Build Aggregates**: Pre-calculate summary tables
5. **Data Quality**: Run validation checks

### Refresh Schedule
- **Full Refresh**: Daily (or hourly for real-time needs)
- **Incremental**: Not yet implemented (future enhancement)

### Command
```bash
# Full ETL with transformations
uv run storemate-cli sync-to-bigquery

# Just transformations (if raw data already loaded)
uv run storemate-cli run-transformations

# View table stats
uv run storemate-cli show-table-stats
```

## Migration from Raw Queries

### Before (Slow, Complex)
```sql
SELECT
  REGEXP_EXTRACT(item, r'<B>([^<]+)') as category,
  SUM(CAST(REGEXP_EXTRACT(item, r'<E>([^<]+)') AS FLOAT64)) as revenue
FROM claim,
UNNEST(SPLIT(INV_ITEM, '<Z>')) as item
GROUP BY 1;
```

### After (Fast, Simple)
```sql
SELECT
  item_category,
  SUM(total_price) as revenue
FROM fact_order_items fi
JOIN dim_items i ON fi.item_key = i.item_key
GROUP BY item_category;
```

## Benefits

1. **10-100x Faster Queries**: Pre-joined, pre-parsed, indexed
2. **Simpler SQL**: No regex parsing, no complex joins
3. **Better Data Quality**: Validated, no nulls, consistent
4. **Rich Analytics**: Customer segments, trends, cohorts
5. **Scalable**: Handles growth without query performance degradation

## Next Steps

1. ✅ Run first transformation: `uv run storemate-cli sync-to-bigquery`
2. ✅ Verify with: `uv run storemate-cli show-table-stats`
3. ✅ Update Looker Studio queries to use dimensional model
4. 📊 Build dashboards using optimized queries
5. 🚀 Set up automated daily refresh

---

**Questions?** Check the transformation SQL files in `transformations/` for implementation details.

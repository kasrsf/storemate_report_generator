# Looker Studio Dashboard Guide

Complete guide to building real-time dashboards for your StoreMate dry cleaning business using Google Looker Studio.

## Table of Contents

1. [Dashboard Overview](#dashboard-overview)
2. [Getting Started](#getting-started)
3. [Dashboard Templates](#dashboard-templates)
4. [Chart Examples](#chart-examples)
5. [Date Filters](#date-filters)
6. [Best Practices](#best-practices)
7. [Advanced Features](#advanced-features)

---

## Dashboard Overview

### Recommended Dashboard Structure

**Dashboard 1: Business Overview**
- Daily sales trends
- Order volume
- Payment method breakdown
- Key performance indicators (KPIs)

**Dashboard 2: Operations**
- Drops vs pickups
- Item analysis
- Processing times
- Staff performance

**Dashboard 3: Customer Insights**
- Top customers
- Customer retention
- Average order value by customer
- Visit frequency

---

## Getting Started

### Step 1: Create Your First Dashboard

1. Go to [Looker Studio](https://lookerstudio.google.com/)
2. Click **"Create"** → **"Report"**
3. Select **"BigQuery"** as data source
4. Choose your project, dataset, and table
5. Click **"Add to Report"**

### Step 2: Set Up Date Range Filter

1. Add → **Date Range Control**
2. Drag to top of dashboard
3. Set default range: **"Last 30 days"**
4. Enable **"Comparison date range"** to show vs previous period

### Step 3: Add Title and Branding

1. Add → **Text box**
2. Enter business name: **"StoreMate Daily Reports"**
3. Style: Font size 24, Bold
4. Optional: Add logo (Insert → Image → Upload)

---

## Dashboard Templates

### Template 1: Executive Dashboard

**Purpose**: High-level overview for business owners

**Layout**:
```
┌────────────────────────────────────────────────┐
│  StoreMate Business Overview  │  [Date Filter] │
├──────────┬──────────┬──────────┬───────────────┤
│  SALES   │  ORDERS  │   AVG    │  COMPARE vs   │
│ $12,345  │   234    │  $52.78  │  YESTERDAY    │
├──────────┴──────────┴──────────┴───────────────┤
│                                                 │
│        Daily Sales Trend (Line Chart)          │
│                                                 │
├────────────────────┬────────────────────────────┤
│                    │                            │
│  Sales by Payment  │   Top 10 Customers        │
│   (Pie Chart)      │      (Table)              │
│                    │                            │
└────────────────────┴────────────────────────────┘
```

**Data Sources**:
- Use `1_report_orders_daily.sql` for trend line
- Use `2_sales_breakdown_daily.sql` for payment pie chart
- Use `5_customer_drops.sql` for top customers

#### Creating Scorecards (KPI Cards)

1. Add → **Scorecard**
2. **Metric**: `total_amount` (or `SUM(AMNT_DUE)`)
3. **Date range dimension**: `date`
4. **Style**:
   - Compact numbers: On
   - Show comparison: Previous period
   - Comparison label: "vs Last Period"

### Template 2: Operations Dashboard

**Purpose**: Daily operations tracking

**Key Metrics**:
- Orders dropped today
- Orders ready for pickup
- Items by category
- Processing backlog

**Charts**:

1. **Drops vs Pickups (Bar Chart)**
   - Data: `3_order_drops_pickups.sql`
   - Dimension: `type`
   - Metric: `number_of_orders`, `total_sales`

2. **Items by Category (Stacked Bar)**
   - Data: `4_item_drops.sql`
   - Dimension: `item_category`
   - Metric: `total_quantity`, `total_price`
   - Sort: By `total_price` descending

3. **Processing Timeline (Time Series)**
   - Data: `claim` table
   - Dimension: `DATE_IN` (formatted as date)
   - Metric: `COUNT(INV_NUM)`
   - Breakdown: `item_category`

### Template 3: Customer Analytics

**Purpose**: Understanding customer behavior

**Key Charts**:

1. **Customer Lifetime Value (Table)**
   - Data: `5_customer_drops.sql`
   - Dimensions: `customer_name`, `telephone_number`
   - Metrics: `total_visits`, `total_spend_all_visits`, `dropped_value`
   - Sort: By `total_spend_all_visits` descending
   - Rows per page: 25

2. **New vs Returning Customers (Pie Chart)**
   - Data: `claim` table
   - Create calculated field:
     ```
     IF(
       COUNT_DISTINCT(INV_NUM) = 1,
       "New Customer",
       "Returning Customer"
     )
     ```
   - Dimension: Calculated field
   - Metric: `COUNT(DISTINCT ACCT_NUM)`

3. **Average Order Value by Customer Segment**
   - Data: `5_customer_drops.sql`
   - Dimension: Create segments based on `total_visits`
   - Metric: `AVG(dropped_value)`

---

## Chart Examples

### Example 1: Daily Sales Trend

**Chart Type**: Time Series
**Data Source**: Custom query using `1_report_orders_daily.sql`

**Configuration**:
- **Date Range Dimension**: `date`
- **Dimension**: `date`
- **Metric**: `total_amount`
- **Optional Metric**: `num_orders` (on right axis)

**Style**:
- Line type: Smooth
- Show data labels: On milestones only
- Trendline: 7-day moving average

### Example 2: Payment Method Breakdown

**Chart Type**: Pie Chart
**Data Source**: Custom query using `2_sales_breakdown_daily.sql`

**Configuration**:
- **Dimension**: Create calculated field to unpivot:
  ```sql
  CASE
    WHEN metric_name = 'cash' THEN 'Cash'
    WHEN metric_name = 'debit' THEN 'Debit Card'
    WHEN metric_name = 'credit' THEN 'Credit Card'
  END
  ```
- **Metric**: `SUM(amount)`

**Style**:
- Slice colors: Green (cash), Blue (debit), Orange (credit)
- Show percentage labels: Yes
- Legend position: Right

### Example 3: Top Items Table

**Chart Type**: Table with Heat Map
**Data Source**: Custom query using `4_item_drops.sql`

**Configuration**:
- **Dimensions**: `item_category`, `item_type`
- **Metrics**:
  - `total_quantity` (rename to "Qty")
  - `total_price` (rename to "Revenue")
  - Calculated field: `total_price / total_quantity` (rename to "Avg Price")

**Style**:
- Row numbers: Show
- Rows per page: 20
- Sort: By "Revenue" descending
- Heat map: Enable on "Revenue" column (green gradient)

### Example 4: Geographic Map

If you have address data:

**Chart Type**: Geo Chart
**Data Source**: `custlist` or `claim` table

**Configuration**:
- **Location**: Use `TEL_NUM` area code or address field
- **Metric**: `COUNT(DISTINCT ACCT_NUM)` (customer count)
- **Bubble color**: `SUM(AMNT_DUE)` (total sales)

**Map Settings**:
- Map type: Bubble map
- Zoom area: Your region/country
- Bubble size: Logarithmic scale

---

## Date Filters

### Using Dashboard Date Range Filter

When using custom SQL queries, replace hardcoded dates with parameters:

**Original query** (with DECLARE):
```sql
DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);
DECLARE end_date DATE DEFAULT CURRENT_DATE();

WHERE date BETWEEN start_date AND end_date
```

**Modified for Looker** (with parameters):
```sql
WHERE date BETWEEN @DS_START_DATE AND @DS_END_DATE
```

Looker Studio automatically populates:
- `@DS_START_DATE` - Start date from date range filter
- `@DS_END_DATE` - End date from date range filter

### Date Comparison

Enable comparison in date range filter to show:
- **This period**: Selected date range
- **Previous period**: Automatically calculated comparison range
- **% Change**: Automatic calculation

Example: "This Week vs Last Week" or "This Month vs Last Month"

---

## Best Practices

### Performance Optimization

1. **Use Aggregated Tables**
   ```sql
   CREATE TABLE `project.dataset.daily_summary` AS
   SELECT
       FORMAT_DATE('%Y-%m-%d', date) as date,
       SUM(total_amount) as daily_sales,
       COUNT(*) as order_count
   FROM `project.dataset.claim`
   GROUP BY 1;
   ```

2. **Limit Date Ranges**
   - Default to last 30-90 days
   - Add dropdown filter for "Quick Ranges":
     - Last 7 days
     - Last 30 days
     - Last quarter
     - Year to date

3. **Use Data Blending Carefully**
   - Blending multiple tables can slow performance
   - Pre-join in BigQuery when possible

4. **Cache Data**
   - In data source settings → enable "Data freshness"
   - Set to 4-12 hours for daily reports
   - Use "Refresh" button to force update

### Design Best Practices

1. **Visual Hierarchy**
   - Most important metrics at top
   - Use larger fonts for KPIs
   - Group related charts together

2. **Color Consistency**
   - Use same colors for same metrics across dashboards
   - Example: Revenue = Green, Orders = Blue, Customers = Orange

3. **White Space**
   - Don't overcrowd dashboards
   - Leave margins between charts
   - Use section dividers

4. **Responsive Design**
   - Test on mobile devices
   - Use grid layout for alignment
   - Make charts stack on small screens

### Data Accuracy

1. **Add Data Freshness Indicator**
   - Add text box: "Last updated: [timestamp]"
   - Use calculated field: `CURRENT_DATETIME()`

2. **Show Sample Size**
   - Include row count in tables
   - Add note: "Based on X orders"

3. **Handle Null Values**
   - Use `COALESCE()` to replace nulls
   - Add filters to exclude incomplete data

4. **Document Definitions**
   - Add info tooltips to metrics
   - Create glossary page in dashboard
   - Example: "Revenue = Total sales after discounts"

---

## Advanced Features

### Calculated Fields

**Example 1: Order Completion Rate**
```
(Picked Orders / Dropped Orders) * 100
```

**Example 2: Customer Segmentation**
```
CASE
  WHEN total_visits >= 50 THEN "VIP"
  WHEN total_visits >= 20 THEN "Frequent"
  WHEN total_visits >= 5 THEN "Regular"
  ELSE "Occasional"
END
```

**Example 3: Revenue per Item**
```
SUM(total_price) / SUM(total_quantity)
```

### Data Blending

Combine data from multiple tables:

1. **Add Data Source**: Add second BigQuery table
2. **Create Blend**: Right-click chart → Blend Data
3. **Join Configuration**:
   - Join key: `ACCT_NUM` or `DATE_IN`
   - Join type: Left outer (or inner)
4. **Select Metrics**: Choose metrics from each table

**Example**: Blend `claim` with `custlist` to show customer demographics with orders.

### Filters and Controls

1. **Dropdown Filter**
   - Add → Filter Control → Dropdown
   - Dimension: `item_category` or `EMP_ID`
   - Allow multiple selections: Yes

2. **Search Filter**
   - Add → Filter Control → Search Box
   - Dimension: `customer_name`
   - Match type: Contains

3. **Slider Filter**
   - Add → Filter Control → Slider
   - Dimension: `total_amount`
   - Min/Max: Auto or custom range

### Sharing and Permissions

1. **Share with Team**
   - Click "Share" → Enter emails
   - Set permission: View or Edit

2. **Embed in Website**
   - File → Embed Report
   - Copy iframe code
   - Paste in your website

3. **Schedule Email Reports**
   - File → Schedule Email Delivery
   - Set frequency: Daily, Weekly, Monthly
   - Add recipients
   - Choose format: PDF or link

4. **Export Options**
   - File → Download → PDF
   - Or export individual charts as CSV

---

## Template Dashboards

### Quick Start: Pre-built Dashboard

Create this dashboard in 15 minutes:

**Title**: StoreMate Daily Dashboard

**Row 1** (KPI Scorecards):
- Total Sales Today
- Orders Today
- Avg Order Value
- % vs Yesterday

**Row 2** (Trend Line):
- Last 30 Days Sales Trend

**Row 3** (Split Charts):
- Payment Methods (Pie) | Top Customers (Table)

**Row 4** (Operations):
- Drops vs Pickups (Bar) | Top Items (Table)

**Step-by-step**:
1. Create blank report
2. Add date range filter (top right)
3. Add 4 scorecards using `1_report_orders_daily.sql`
4. Add time series chart
5. Add pie chart using `2_sales_breakdown_daily.sql`
6. Add tables from customer and item queries
7. Style with theme colors and fonts

---

## Troubleshooting

### Issue: Dashboard is slow

**Solutions**:
1. Reduce date range default (30 days instead of 1 year)
2. Use aggregated tables instead of raw data
3. Limit number of charts per page (max 10-12)
4. Enable data caching

### Issue: Data doesn't refresh

**Solutions**:
1. Click "Refresh Data" button
2. Check data source freshness settings
3. Verify BigQuery data is updated
4. Clear browser cache

### Issue: Chart shows "No data"

**Check**:
1. Date range filter includes data dates
2. Filters aren't too restrictive
3. SQL query is valid in BigQuery
4. Permissions are correct

### Issue: Numbers don't match

**Verify**:
1. Aggregation method (SUM vs AVG vs COUNT)
2. Filters applied to chart vs data source
3. Deduplicate if needed (`COUNT DISTINCT`)
4. Check for null values

---

## Resources

- **Looker Studio Gallery**: https://lookerstudio.google.com/gallery
- **Help Center**: https://support.google.com/looker-studio
- **Community**: https://www.en.advertisercommunity.com/t5/Looker-Studio/ct-p/looker-studio
- **Templates**: Search "retail dashboard" or "POS dashboard" in gallery

**Pro Tip**: Explore the template gallery for inspiration and copy charts you like!

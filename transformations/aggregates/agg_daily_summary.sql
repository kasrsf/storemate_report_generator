-- Aggregate Table: Daily Summary
-- Pre-aggregated daily metrics for fast dashboard performance
-- Grain: One row per date

CREATE OR REPLACE TABLE `{project_id}.{analytics_dataset}.agg_daily_summary` AS

SELECT
  -- Date key
  d.date_key,
  d.date,
  d.year,
  d.quarter,
  d.month,
  d.year_month,
  d.day_of_week,
  d.day_name,
  d.is_weekend,

  -- Order counts
  COUNT(DISTINCT fo.order_key) as num_orders,
  COUNT(DISTINCT CASE WHEN fo.is_picked_up THEN fo.order_key END) as num_orders_picked_up,
  COUNT(DISTINCT CASE WHEN NOT fo.is_picked_up THEN fo.order_key END) as num_orders_pending,

  -- Customer metrics
  COUNT(DISTINCT fo.customer_key) as num_customers,
  COUNT(DISTINCT CASE
    WHEN c.lifetime_orders = 1 THEN fo.customer_key
  END) as num_new_customers,

  -- Item metrics
  SUM(fo.total_items) as total_items,
  ROUND(AVG(fo.total_items), 2) as avg_items_per_order,

  -- Revenue metrics
  ROUND(SUM(fo.subtotal), 2) as total_subtotal,
  ROUND(SUM(fo.discount_amount), 2) as total_discounts,
  ROUND(SUM(fo.amount_due), 2) as total_revenue,
  ROUND(AVG(fo.amount_due), 2) as avg_order_value,
  ROUND(SUM(fo.amount_due) / NULLIF(SUM(fo.total_items), 0), 2) as revenue_per_item,

  -- Payment totals
  ROUND(SUM(fo.amount_paid), 2) as total_paid,
  ROUND(SUM(fo.balance_due), 2) as total_balance_due,

  -- Order size distribution
  COUNT(DISTINCT CASE WHEN fo.order_size = 'Large' THEN fo.order_key END) as num_large_orders,
  COUNT(DISTINCT CASE WHEN fo.order_size = 'Medium' THEN fo.order_key END) as num_medium_orders,
  COUNT(DISTINCT CASE WHEN fo.order_size = 'Small' THEN fo.order_key END) as num_small_orders,

  -- Discount metrics
  COUNT(DISTINCT CASE WHEN fo.has_discount THEN fo.order_key END) as num_discounted_orders,
  ROUND(AVG(CASE WHEN fo.has_discount THEN fo.discount_percentage END), 4) as avg_discount_rate,

  -- Processing time metrics
  ROUND(AVG(fo.days_to_pickup), 2) as avg_days_to_pickup,
  ROUND(STDDEV(fo.days_to_pickup), 2) as stddev_days_to_pickup,

  -- Performance indicators
  ROUND(
    COUNT(DISTINCT CASE WHEN fo.is_picked_up THEN fo.order_key END) /
    NULLIF(COUNT(DISTINCT fo.order_key), 0) * 100,
    2
  ) as pickup_completion_rate,

  ROUND(
    COUNT(DISTINCT CASE WHEN fo.is_paid THEN fo.order_key END) /
    NULLIF(COUNT(DISTINCT fo.order_key), 0) * 100,
    2
  ) as payment_completion_rate,

  -- Metadata
  CURRENT_TIMESTAMP() as created_at,
  CURRENT_TIMESTAMP() as updated_at

FROM `{project_id}.{analytics_dataset}.dim_dates` d
LEFT JOIN `{project_id}.{analytics_dataset}.fact_orders` fo
  ON d.date_key = fo.date_in_key
LEFT JOIN `{project_id}.{analytics_dataset}.dim_customers` c
  ON fo.customer_key = c.customer_key

-- Only include dates with activity or recent dates
WHERE d.date >= (
  SELECT MIN(dd.date)
  FROM `{project_id}.{analytics_dataset}.fact_orders` fo2
  JOIN `{project_id}.{analytics_dataset}.dim_dates` dd ON fo2.date_in_key = dd.date_key
)
  AND d.date <= CURRENT_DATE()

GROUP BY
  d.date_key, d.date, d.year, d.quarter, d.month, d.year_month,
  d.day_of_week, d.day_name, d.is_weekend

ORDER BY d.date DESC;

-- Note: Partitioned table commented out due to BigQuery 4000 partition limit
-- Can be enabled later with monthly or yearly partitioning if needed

-- Create rolling metrics view (7-day, 30-day, 90-day averages)
CREATE OR REPLACE VIEW `{project_id}.{analytics_dataset}.v_daily_summary_with_trends` AS
SELECT
  *,
  -- 7-day rolling averages
  ROUND(AVG(total_revenue) OVER (
    ORDER BY date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ), 2) as revenue_7day_avg,

  ROUND(AVG(num_orders) OVER (
    ORDER BY date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ), 2) as orders_7day_avg,

  -- 30-day rolling averages
  ROUND(AVG(total_revenue) OVER (
    ORDER BY date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ), 2) as revenue_30day_avg,

  ROUND(AVG(num_orders) OVER (
    ORDER BY date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ), 2) as orders_30day_avg,

  -- Growth rates (vs previous day)
  ROUND((total_revenue - LAG(total_revenue) OVER (ORDER BY date)) /
    NULLIF(LAG(total_revenue) OVER (ORDER BY date), 0) * 100, 2) as revenue_growth_pct,

  ROUND((num_orders - LAG(num_orders) OVER (ORDER BY date)) /
    NULLIF(CAST(LAG(num_orders) OVER (ORDER BY date) AS FLOAT64), 0) * 100, 2) as orders_growth_pct

FROM `{project_id}.{analytics_dataset}.agg_daily_summary`
WHERE num_orders > 0  -- Only include days with activity
ORDER BY date DESC;

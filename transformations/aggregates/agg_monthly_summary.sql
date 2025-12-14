-- Aggregate Table: Monthly Summary
-- Pre-aggregated monthly metrics for trend analysis
-- Grain: One row per month

CREATE OR REPLACE TABLE `{project_id}.{analytics_dataset}.agg_monthly_summary` AS

SELECT
  -- Date grouping
  d.year,
  d.month,
  d.month_name,
  d.year_month,
  MIN(d.date) as month_start_date,
  MAX(d.date) as month_end_date,
  COUNT(DISTINCT d.date) as days_in_period,

  -- Order metrics
  COUNT(DISTINCT fo.order_key) as num_orders,
  COUNT(DISTINCT CASE WHEN fo.is_picked_up THEN fo.order_key END) as num_orders_picked_up,
  ROUND(AVG(daily_orders), 2) as avg_orders_per_day,

  -- Customer metrics
  COUNT(DISTINCT fo.customer_key) as num_customers,
  COUNT(DISTINCT CASE WHEN FORMAT_DATE('%Y-%m', c.first_visit_date) = d.year_month THEN fo.customer_key END) as num_new_customers,
  ROUND(COUNT(DISTINCT fo.customer_key) / NULLIF(COUNT(DISTINCT d.date), 0), 2) as avg_customers_per_day,

  -- Revenue metrics
  ROUND(SUM(fo.amount_due), 2) as total_revenue,
  ROUND(AVG(fo.amount_due), 2) as avg_order_value,
  ROUND(SUM(fo.amount_due) / NULLIF(COUNT(DISTINCT d.date), 0), 2) as avg_revenue_per_day,
  ROUND(SUM(fo.amount_due) / NULLIF(COUNT(DISTINCT fo.customer_key), 0), 2) as revenue_per_customer,

  -- Item metrics
  SUM(fo.total_items) as total_items,
  ROUND(AVG(fo.total_items), 2) as avg_items_per_order,

  -- Payment totals
  ROUND(SUM(fo.amount_paid), 2) as total_paid,

  -- Discounts
  ROUND(SUM(fo.discount_amount), 2) as total_discounts,
  COUNT(DISTINCT CASE WHEN fo.has_discount THEN fo.order_key END) as num_discounted_orders,

  -- Processing
  ROUND(AVG(fo.days_to_pickup), 2) as avg_days_to_pickup,

  -- Metadata
  CURRENT_TIMESTAMP() as created_at,
  CURRENT_TIMESTAMP() as updated_at

FROM `{project_id}.{analytics_dataset}.dim_dates` d
LEFT JOIN `{project_id}.{analytics_dataset}.fact_orders` fo
  ON d.date_key = fo.date_in_key
LEFT JOIN `{project_id}.{analytics_dataset}.dim_customers` c
  ON fo.customer_key = c.customer_key
LEFT JOIN (
  -- Calculate daily order counts for averaging
  SELECT
    dd.year_month,
    dd.date,
    COUNT(DISTINCT ffo.order_key) as daily_orders
  FROM `{project_id}.{analytics_dataset}.dim_dates` dd
  LEFT JOIN `{project_id}.{analytics_dataset}.fact_orders` ffo
    ON dd.date_key = ffo.date_in_key
  GROUP BY dd.year_month, dd.date
) daily
  ON d.year_month = daily.year_month AND d.date = daily.date

WHERE d.date <= CURRENT_DATE()
GROUP BY d.year, d.month, d.month_name, d.year_month
ORDER BY d.year DESC, d.month DESC;

-- Create view with month-over-month growth
CREATE OR REPLACE VIEW `{project_id}.{analytics_dataset}.v_monthly_summary_with_growth` AS
SELECT
  *,
  -- Month-over-month growth
  ROUND((total_revenue - LAG(total_revenue) OVER (ORDER BY year, month)) /
    NULLIF(LAG(total_revenue) OVER (ORDER BY year, month), 0) * 100, 2) as revenue_mom_growth,

  ROUND((num_orders - LAG(num_orders) OVER (ORDER BY year, month)) /
    NULLIF(CAST(LAG(num_orders) OVER (ORDER BY year, month) AS FLOAT64), 0) * 100, 2) as orders_mom_growth,

  ROUND((num_customers - LAG(num_customers) OVER (ORDER BY year, month)) /
    NULLIF(CAST(LAG(num_customers) OVER (ORDER BY year, month) AS FLOAT64), 0) * 100, 2) as customers_mom_growth,

  -- Year-over-year growth
  ROUND((total_revenue - LAG(total_revenue, 12) OVER (ORDER BY year, month)) /
    NULLIF(LAG(total_revenue, 12) OVER (ORDER BY year, month), 0) * 100, 2) as revenue_yoy_growth,

  ROUND((num_orders - LAG(num_orders, 12) OVER (ORDER BY year, month)) /
    NULLIF(CAST(LAG(num_orders, 12) OVER (ORDER BY year, month) AS FLOAT64), 0) * 100, 2) as orders_yoy_growth

FROM `{project_id}.{analytics_dataset}.agg_monthly_summary`
ORDER BY year DESC, month DESC;

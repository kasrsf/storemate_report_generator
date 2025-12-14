-- Dimension: Employees
-- Creates an employee dimension with performance metrics
-- Tracks employee activity and productivity

CREATE OR REPLACE TABLE `{project_id}.{analytics_dataset}.dim_employees` AS

WITH employee_metrics AS (
  SELECT
    EMP_ID,

    -- Count orders processed
    COUNT(DISTINCT INV_NUM) as orders_processed,
    SUM(CAST(AMNT_DUE AS FLOAT64)) as total_revenue_generated,
    AVG(CAST(AMNT_DUE AS FLOAT64)) as avg_order_value,
    SUM(CAST(TOT_ITEM AS INT64)) as total_items_processed,

    -- Date range of activity
    MIN(CAST(DATE_IN AS DATE)) as first_order_date,
    MAX(CAST(DATE_IN AS DATE)) as last_order_date,

    -- Days active
    DATE_DIFF(
      MAX(CAST(DATE_IN AS DATE)),
      MIN(CAST(DATE_IN AS DATE)),
      DAY
    ) + 1 as days_active

  FROM `{project_id}.{raw_dataset}.claim`
  WHERE EMP_ID IS NOT NULL
    AND DATE_IN IS NOT NULL
  GROUP BY EMP_ID
),

employee_stats AS (
  SELECT
    *,
    -- Calculate productivity metrics
    ROUND(orders_processed / NULLIF(days_active, 0), 2) as avg_orders_per_day,
    ROUND(total_revenue_generated / NULLIF(orders_processed, 0), 2) as revenue_per_order,

    -- Performance ranking
    ROW_NUMBER() OVER (ORDER BY total_revenue_generated DESC) as revenue_rank,
    ROW_NUMBER() OVER (ORDER BY orders_processed DESC) as volume_rank,

    -- Determine if currently active
    DATE_DIFF(CURRENT_DATE(), last_order_date, DAY) as days_since_last_order

  FROM employee_metrics
)

SELECT
  -- Surrogate key
  ROW_NUMBER() OVER (ORDER BY EMP_ID) as employee_key,

  -- Natural key
  EMP_ID as employee_id,

  -- Could join with emplist table here if needed for names
  CONCAT('Employee ', EMP_ID) as employee_name,  -- Placeholder

  -- Performance metrics
  orders_processed,
  total_items_processed,
  ROUND(total_revenue_generated, 2) as total_revenue_generated,
  ROUND(avg_order_value, 2) as avg_order_value,

  -- Activity dates
  first_order_date,
  last_order_date,
  days_active,
  days_since_last_order,

  -- Productivity metrics
  avg_orders_per_day,
  revenue_per_order,
  ROUND(total_items_processed / NULLIF(orders_processed, 0), 2) as avg_items_per_order,

  -- Rankings
  revenue_rank,
  volume_rank,

  -- Performance tier
  CASE
    WHEN revenue_rank <= 3 THEN 'Top Performer'
    WHEN revenue_rank <= 10 THEN 'High Performer'
    WHEN revenue_rank <= 20 THEN 'Standard Performer'
    ELSE 'Developing'
  END as performance_tier,

  -- Flags
  CASE WHEN days_since_last_order <= 30 THEN TRUE ELSE FALSE END as is_active,
  CASE WHEN avg_orders_per_day >= 10 THEN TRUE ELSE FALSE END as is_high_volume,
  CASE WHEN avg_order_value >= 50 THEN TRUE ELSE FALSE END as is_high_value,

  -- Metadata
  CURRENT_TIMESTAMP() as created_at,
  CURRENT_TIMESTAMP() as updated_at

FROM employee_stats
ORDER BY total_revenue_generated DESC;

-- Create views for employee segments
CREATE OR REPLACE VIEW `{project_id}.{analytics_dataset}.v_active_employees` AS
SELECT * FROM `{project_id}.{analytics_dataset}.dim_employees`
WHERE is_active = TRUE
ORDER BY total_revenue_generated DESC;

CREATE OR REPLACE VIEW `{project_id}.{analytics_dataset}.v_top_performers` AS
SELECT * FROM `{project_id}.{analytics_dataset}.dim_employees`
WHERE performance_tier IN ('Top Performer', 'High Performer')
ORDER BY revenue_rank;

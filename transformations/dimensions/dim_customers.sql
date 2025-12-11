-- Dimension: Customers
-- Creates a customer dimension with lifetime metrics and segmentation
-- Includes SCD Type 2 attributes for tracking changes over time

CREATE OR REPLACE TABLE `{project_id}.{dataset_name}.dim_customers` AS

WITH customer_lifetime_metrics AS (
  SELECT
    ACCT_NUM,
    -- Use most recent values for slowly changing attributes
    ARRAY_AGG(CUST_NAME ORDER BY DATE_IN DESC LIMIT 1)[OFFSET(0)] as customer_name,
    ARRAY_AGG(TEL_NUM ORDER BY DATE_IN DESC LIMIT 1)[OFFSET(0)] as phone_number,

    -- Lifetime metrics
    COUNT(DISTINCT INV_NUM) as lifetime_orders,
    SUM(CAST(TOT_ITEM AS INT64)) as lifetime_items,
    SUM(CAST(AMNT_DUE AS FLOAT64)) as lifetime_revenue,
    AVG(CAST(AMNT_DUE AS FLOAT64)) as avg_order_value,

    -- First and last visit
    MIN(CAST(DATE_IN AS DATE)) as first_visit_date,
    MAX(CAST(DATE_IN AS DATE)) as last_visit_date,

    -- Recency
    DATE_DIFF(CURRENT_DATE(), MAX(CAST(DATE_IN AS DATE)), DAY) as days_since_last_visit,

    -- Frequency calculation (days between first and last visit)
    DATE_DIFF(
      MAX(CAST(DATE_IN AS DATE)),
      MIN(CAST(DATE_IN AS DATE)),
      DAY
    ) as customer_lifetime_days

  FROM `{project_id}.{dataset_name}.claim`
  WHERE ACCT_NUM IS NOT NULL
    AND DATE_IN IS NOT NULL
  GROUP BY ACCT_NUM
),

customer_segments AS (
  SELECT
    *,
    -- RFM Segmentation
    CASE
      WHEN days_since_last_visit <= 30 THEN 'Active'
      WHEN days_since_last_visit <= 90 THEN 'At Risk'
      WHEN days_since_last_visit <= 180 THEN 'Churning'
      ELSE 'Churned'
    END as recency_segment,

    CASE
      WHEN lifetime_orders >= 50 THEN 'VIP'
      WHEN lifetime_orders >= 20 THEN 'Loyal'
      WHEN lifetime_orders >= 10 THEN 'Regular'
      WHEN lifetime_orders >= 5 THEN 'Occasional'
      ELSE 'New'
    END as frequency_segment,

    CASE
      WHEN lifetime_revenue >= 5000 THEN 'High Value'
      WHEN lifetime_revenue >= 2000 THEN 'Medium Value'
      WHEN lifetime_revenue >= 500 THEN 'Low Value'
      ELSE 'Very Low Value'
    END as monetary_segment,

    -- Visit frequency (orders per month)
    CASE
      WHEN customer_lifetime_days > 0 THEN
        ROUND(lifetime_orders / (customer_lifetime_days / 30.0), 2)
      ELSE 0
    END as avg_orders_per_month

  FROM customer_lifetime_metrics
)

SELECT
  -- Surrogate key
  ROW_NUMBER() OVER (ORDER BY ACCT_NUM) as customer_key,

  -- Natural key
  ACCT_NUM as account_number,

  -- Attributes
  COALESCE(customer_name, 'Unknown') as customer_name,
  phone_number,

  -- Lifetime metrics
  lifetime_orders,
  lifetime_items,
  ROUND(lifetime_revenue, 2) as lifetime_revenue,
  ROUND(avg_order_value, 2) as avg_order_value,

  -- Dates
  first_visit_date,
  last_visit_date,
  days_since_last_visit,
  customer_lifetime_days,

  -- Derived metrics
  avg_orders_per_month,
  ROUND(lifetime_items / NULLIF(lifetime_orders, 0), 2) as avg_items_per_order,

  -- Segments
  recency_segment,
  frequency_segment,
  monetary_segment,

  -- Combined RFM segment
  CONCAT(
    SUBSTR(recency_segment, 1, 1),
    SUBSTR(frequency_segment, 1, 1),
    SUBSTR(monetary_segment, 1, 1)
  ) as rfm_segment,

  -- Overall customer segment (business logic)
  CASE
    WHEN recency_segment IN ('Active', 'At Risk') AND frequency_segment IN ('VIP', 'Loyal') THEN 'Champion'
    WHEN recency_segment = 'Active' AND frequency_segment IN ('Regular', 'Occasional') THEN 'Promising'
    WHEN recency_segment = 'At Risk' AND frequency_segment IN ('VIP', 'Loyal', 'Regular') THEN 'Need Attention'
    WHEN recency_segment IN ('Churning', 'Churned') AND lifetime_revenue >= 1000 THEN 'Win Back'
    WHEN frequency_segment = 'New' THEN 'New Customer'
    ELSE 'Standard'
  END as customer_segment,

  -- Flags
  CASE WHEN days_since_last_visit <= 30 THEN TRUE ELSE FALSE END as is_active,
  CASE WHEN lifetime_orders = 1 THEN TRUE ELSE FALSE END as is_one_time_customer,
  CASE WHEN days_since_last_visit > 365 THEN TRUE ELSE FALSE END as is_dormant,

  -- Metadata
  CURRENT_TIMESTAMP() as created_at,
  CURRENT_TIMESTAMP() as updated_at

FROM customer_segments
WHERE ACCT_NUM IS NOT NULL
ORDER BY lifetime_revenue DESC;

-- Create views for common segments
CREATE OR REPLACE VIEW `{project_id}.{dataset_name}.v_active_customers` AS
SELECT * FROM `{project_id}.{dataset_name}.dim_customers`
WHERE is_active = TRUE;

CREATE OR REPLACE VIEW `{project_id}.{dataset_name}.v_vip_customers` AS
SELECT * FROM `{project_id}.{dataset_name}.dim_customers`
WHERE customer_segment IN ('Champion', 'VIP');

CREATE OR REPLACE VIEW `{project_id}.{dataset_name}.v_at_risk_customers` AS
SELECT * FROM `{project_id}.{dataset_name}.dim_customers`
WHERE customer_segment = 'Need Attention';

-- Fact Table: Orders
-- Order-level transaction fact table
-- Grain: One row per order (invoice/claim)

CREATE OR REPLACE TABLE `{project_id}.{analytics_dataset}.fact_orders` AS

WITH claim_data AS (
  SELECT
    c.*,
    -- Join to get surrogate keys from dimensions
    cust.customer_key,
    emp.employee_key,
    dd_in.date_key as date_in_key,
    dd_pick.date_key as date_pick_key

  FROM `{project_id}.{raw_dataset}.claim` c

  -- Join to customer dimension
  LEFT JOIN `{project_id}.{analytics_dataset}.dim_customers` cust
    ON c.ACCT_NUM = cust.account_number

  -- Join to employee dimension
  LEFT JOIN `{project_id}.{analytics_dataset}.dim_employees` emp
    ON c.EMP_ID = emp.employee_id

  -- Join to date dimension for drop-off date
  LEFT JOIN `{project_id}.{analytics_dataset}.dim_dates` dd_in
    ON FORMAT_DATE('%Y%m%d', CAST(c.DATE_IN AS DATE)) = dd_in.date_key

  -- Join to date dimension for pickup date
  LEFT JOIN `{project_id}.{analytics_dataset}.dim_dates` dd_pick
    ON FORMAT_DATE('%Y%m%d', CAST(c.DATE_PICK AS DATE)) = dd_pick.date_key
)

SELECT
  -- Surrogate key
  ROW_NUMBER() OVER (ORDER BY INV_NUM) as order_key,

  -- Foreign keys to dimensions
  customer_key,
  employee_key,
  date_in_key,
  date_pick_key,

  -- Degenerate dimensions (transaction identifiers)
  INV_NUM as invoice_number,
  BOL_NUM as bill_of_lading_number,

  -- Order attributes
  TOT_ITEM as total_items,
  REMARK as order_notes,

  -- Financial measures
  CAST(SUB_TOT AS FLOAT64) as subtotal,
  CAST(DISCOUNT AS FLOAT64) as discount_amount,
  CAST(AMNT_DUE AS FLOAT64) as amount_due,
  CAST(AMNT_PAID AS FLOAT64) as amount_paid,
  CAST(AMNT_DUE AS FLOAT64) - CAST(AMNT_PAID AS FLOAT64) as balance_due,

  -- Derived measures
  CASE
    WHEN CAST(SUB_TOT AS FLOAT64) > 0 THEN
      CAST(DISCOUNT AS FLOAT64) / CAST(SUB_TOT AS FLOAT64)
    ELSE 0
  END as discount_percentage,

  CASE
    WHEN CAST(TOT_ITEM AS INT64) > 0 THEN
      CAST(AMNT_DUE AS FLOAT64) / CAST(TOT_ITEM AS INT64)
    ELSE 0
  END as revenue_per_item,

  -- Order status flags
  CASE
    WHEN DATE_PICK IS NOT NULL THEN TRUE
    ELSE FALSE
  END as is_picked_up,

  CASE
    WHEN CAST(AMNT_PAID AS FLOAT64) > 0 THEN TRUE
    ELSE FALSE
  END as is_paid,

  CASE
    WHEN CAST(AMNT_DUE AS FLOAT64) > CAST(AMNT_PAID AS FLOAT64) THEN TRUE
    ELSE FALSE
  END as has_balance,

  CASE
    WHEN CAST(DISCOUNT AS FLOAT64) > 0 THEN TRUE
    ELSE FALSE
  END as has_discount,

  -- Payment status
  CASE
    WHEN CAST(AMNT_PAID AS FLOAT64) > 0 THEN 'Paid'
    ELSE 'Not Paid'
  END as payment_status,

  -- Order type
  CASE
    WHEN DATE_PICK IS NULL THEN 'Dropped - Not Picked Up'
    WHEN CAST(AMNT_PAID AS FLOAT64) = 0 THEN 'Picked Up - Not Paid'
    ELSE 'Completed'
  END as order_status,

  -- Processing time
  CASE
    WHEN DATE_PICK IS NOT NULL AND DATE_IN IS NOT NULL THEN
      DATE_DIFF(
        CAST(DATE_PICK AS DATE),
        CAST(DATE_IN AS DATE),
        DAY
      )
    ELSE NULL
  END as days_to_pickup,

  -- Order size classification
  CASE
    WHEN CAST(AMNT_DUE AS FLOAT64) >= 100 THEN 'Large'
    WHEN CAST(AMNT_DUE AS FLOAT64) >= 50 THEN 'Medium'
    WHEN CAST(AMNT_DUE AS FLOAT64) >= 20 THEN 'Small'
    ELSE 'Very Small'
  END as order_size,

  -- Metadata
  CURRENT_TIMESTAMP() as created_at,
  CURRENT_TIMESTAMP() as updated_at

FROM claim_data
ORDER BY invoice_number;

-- Note: Partitioned table commented out due to BigQuery 4000 partition limit
-- Can be enabled later with monthly or yearly partitioning if needed

-- Create indexes and views for common queries
CREATE OR REPLACE VIEW `{project_id}.{analytics_dataset}.v_recent_orders` AS
SELECT
  fo.*,
  c.customer_name,
  c.customer_segment,
  d.date as order_date,
  d.year_month
FROM `{project_id}.{analytics_dataset}.fact_orders` fo
LEFT JOIN `{project_id}.{analytics_dataset}.dim_customers` c ON fo.customer_key = c.customer_key
LEFT JOIN `{project_id}.{analytics_dataset}.dim_dates` d ON fo.date_in_key = d.date_key
WHERE d.date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
ORDER BY d.date DESC;

CREATE OR REPLACE VIEW `{project_id}.{analytics_dataset}.v_unpicked_orders` AS
SELECT
  fo.*,
  c.customer_name,
  c.phone_number,
  d.date as drop_off_date,
  DATE_DIFF(CURRENT_DATE(), d.date, DAY) as days_waiting
FROM `{project_id}.{analytics_dataset}.fact_orders` fo
LEFT JOIN `{project_id}.{analytics_dataset}.dim_customers` c ON fo.customer_key = c.customer_key
LEFT JOIN `{project_id}.{analytics_dataset}.dim_dates` d ON fo.date_in_key = d.date_key
WHERE fo.is_picked_up = FALSE
ORDER BY d.date;

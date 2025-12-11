-- Fact Table: Order Items
-- Item-level transaction fact table
-- Grain: One row per item per order

CREATE OR REPLACE TABLE `{project_id}.{dataset_name}.fact_order_items` AS

WITH exploded_items AS (
  SELECT
    c.INV_NUM,
    c.ACCT_NUM,
    c.EMP_ID,
    c.DATE_IN,
    c.DATE_PICK,

    -- Explode items and parse
    item_index,
    item,
    SAFE_CAST(REGEXP_EXTRACT(item, r'([0-9]+)<A>') AS INT64) as quantity,
    REGEXP_EXTRACT(item, r'<A>([^<]+)') AS item_type,
    REGEXP_EXTRACT(item, r'<B>([^<]+)') AS item_category,
    SAFE_CAST(REGEXP_EXTRACT(item, r'<C>([^<]+)') AS FLOAT64) as unit_price,
    SAFE_CAST(REGEXP_EXTRACT(item, r'<E>([^<]+)') AS FLOAT64) as total_price

  FROM `{project_id}.{dataset_name}.claim` c,
  UNNEST(SPLIT(c.INV_ITEM, '<Z>')) AS item WITH OFFSET item_index

  WHERE item IS NOT NULL
    AND item != ''
    AND REGEXP_EXTRACT(item, r'<A>([^<]+)') IS NOT NULL
),

enriched_items AS (
  SELECT
    ei.*,

    -- Join to get surrogate keys
    fo.order_key,
    i.item_key,
    cust.customer_key,
    emp.employee_key,
    dd_in.date_key as date_in_key,
    dd_pick.date_key as date_pick_key

  FROM exploded_items ei

  -- Join to fact_orders
  LEFT JOIN `{project_id}.{dataset_name}.fact_orders` fo
    ON ei.INV_NUM = fo.invoice_number

  -- Join to item dimension
  LEFT JOIN `{project_id}.{dataset_name}.dim_items` i
    ON ei.item_type = i.item_type
    AND ei.item_category = i.item_category
    AND ABS(ei.unit_price - i.standard_unit_price) < 0.01  -- Handle floating point comparison

  -- Join to customer dimension
  LEFT JOIN `{project_id}.{dataset_name}.dim_customers` cust
    ON ei.ACCT_NUM = cust.account_number

  -- Join to employee dimension
  LEFT JOIN `{project_id}.{dataset_name}.dim_employees` emp
    ON ei.EMP_ID = emp.employee_id

  -- Join to date dimensions
  LEFT JOIN `{project_id}.{dataset_name}.dim_dates` dd_in
    ON FORMAT_DATE('%Y%m%d', CAST(ei.DATE_IN AS DATE)) = dd_in.date_key

  LEFT JOIN `{project_id}.{dataset_name}.dim_dates` dd_pick
    ON FORMAT_DATE('%Y%m%d', CAST(ei.DATE_PICK AS DATE)) = dd_pick.date_key
)

SELECT
  -- Surrogate key
  ROW_NUMBER() OVER (ORDER BY INV_NUM, item_index) as order_item_key,

  -- Foreign keys to dimensions
  order_key,
  item_key,
  customer_key,
  employee_key,
  date_in_key,
  date_pick_key,

  -- Degenerate dimensions
  INV_NUM as invoice_number,
  item_index as line_number,

  -- Measures
  quantity,
  ROUND(unit_price, 2) as unit_price,
  ROUND(total_price, 2) as total_price,

  -- Calculated measures
  ROUND(total_price / NULLIF(quantity, 0), 2) as calculated_unit_price,
  CASE
    WHEN ABS(unit_price * quantity - total_price) > 0.01 THEN TRUE
    ELSE FALSE
  END as has_price_variance,

  -- Item status flags
  CASE
    WHEN DATE_PICK IS NOT NULL THEN TRUE
    ELSE FALSE
  END as is_picked_up,

  CASE
    WHEN quantity > 1 THEN TRUE
    ELSE FALSE
  END as is_multi_quantity,

  CASE
    WHEN unit_price > 15 THEN TRUE
    ELSE FALSE
  END as is_premium_service,

  -- Order position metrics
  item_index + 1 as item_position,
  CASE WHEN item_index = 0 THEN TRUE ELSE FALSE END as is_first_item,

  -- Metadata
  CURRENT_TIMESTAMP() as created_at,
  CURRENT_TIMESTAMP() as updated_at

FROM enriched_items
WHERE item_key IS NOT NULL  -- Only include successfully matched items
ORDER BY invoice_number, item_index;

-- Note: Partitioned table commented out due to BigQuery 4000 partition limit
-- Can be enabled later with monthly or yearly partitioning if needed

-- Create views for common analyses
CREATE OR REPLACE VIEW `{project_id}.{dataset_name}.v_item_sales_summary` AS
SELECT
  i.item_category,
  i.item_type,
  i.item_group,
  i.service_type,
  COUNT(DISTINCT foi.order_key) as num_orders,
  SUM(foi.quantity) as total_quantity,
  ROUND(SUM(foi.total_price), 2) as total_revenue,
  ROUND(AVG(foi.unit_price), 2) as avg_unit_price,
  ROUND(AVG(foi.quantity), 2) as avg_quantity_per_order
FROM `{project_id}.{dataset_name}.fact_order_items` foi
JOIN `{project_id}.{dataset_name}.dim_items` i ON foi.item_key = i.item_key
GROUP BY i.item_category, i.item_type, i.item_group, i.service_type
ORDER BY total_revenue DESC;

CREATE OR REPLACE VIEW `{project_id}.{dataset_name}.v_recent_item_sales` AS
SELECT
  foi.*,
  i.item_category,
  i.item_type,
  i.item_group,
  c.customer_name,
  d.date as sale_date
FROM `{project_id}.{dataset_name}.fact_order_items` foi
JOIN `{project_id}.{dataset_name}.dim_items` i ON foi.item_key = i.item_key
JOIN `{project_id}.{dataset_name}.dim_customers` c ON foi.customer_key = c.customer_key
JOIN `{project_id}.{dataset_name}.dim_dates` d ON foi.date_in_key = d.date_key
WHERE d.date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY d.date DESC;

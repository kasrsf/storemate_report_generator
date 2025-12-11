-- Dimension: Items
-- Creates an item dimension from the encoded INV_ITEM field
-- Format: {qty}<A>{type}<B>{category}<C>{unit_price}<E>{total_price}
-- Multiple items separated by <Z>

CREATE OR REPLACE TABLE `{project_id}.{dataset_name}.dim_items` AS

WITH parsed_items AS (
  SELECT
    -- Parse item attributes from the encoded string
    REGEXP_EXTRACT(item, r'<A>([^<]+)') AS item_type,
    REGEXP_EXTRACT(item, r'<B>([^<]+)') AS item_category,
    SAFE_CAST(REGEXP_EXTRACT(item, r'<C>([^<]+)') AS FLOAT64) as unit_price,

    -- Count occurrences for popularity metrics
    COUNT(*) as order_frequency,
    SUM(SAFE_CAST(REGEXP_EXTRACT(item, r'([0-9]+)<A>') AS INT64)) as total_quantity_sold

  FROM `{project_id}.{dataset_name}.claim`,
  UNNEST(SPLIT(INV_ITEM, '<Z>')) AS item
  WHERE item IS NOT NULL
    AND item != ''
    AND REGEXP_EXTRACT(item, r'<A>([^<]+)') IS NOT NULL
    AND REGEXP_EXTRACT(item, r'<B>([^<]+)') IS NOT NULL
  GROUP BY item_type, item_category, unit_price
),

item_metrics AS (
  SELECT
    *,
    -- Calculate average price for items with multiple price points
    AVG(unit_price) OVER (PARTITION BY item_type, item_category) as avg_category_price,

    -- Rank items by popularity
    ROW_NUMBER() OVER (
      PARTITION BY item_category
      ORDER BY order_frequency DESC
    ) as popularity_rank_in_category,

    ROW_NUMBER() OVER (
      ORDER BY order_frequency DESC
    ) as overall_popularity_rank

  FROM parsed_items
)

SELECT
  -- Surrogate key
  ROW_NUMBER() OVER (ORDER BY item_category, item_type, unit_price) as item_key,

  -- Natural key (composite)
  CONCAT(
    COALESCE(item_category, 'Unknown'), '|',
    COALESCE(item_type, 'Unknown'), '|',
    CAST(COALESCE(unit_price, 0) AS STRING)
  ) as item_natural_key,

  -- Attributes
  COALESCE(item_type, 'Unknown') as item_type,
  COALESCE(item_category, 'Unknown') as item_category,
  ROUND(unit_price, 2) as standard_unit_price,

  -- Metrics
  order_frequency,
  total_quantity_sold,
  ROUND(avg_category_price, 2) as avg_category_price,
  popularity_rank_in_category,
  overall_popularity_rank,

  -- Category groupings for reporting
  CASE
    WHEN UPPER(item_category) LIKE '%SHIRT%' OR UPPER(item_category) LIKE '%BLOUSE%' THEN 'Shirts & Tops'
    WHEN UPPER(item_category) LIKE '%PANT%' OR UPPER(item_category) LIKE '%TROUSER%' THEN 'Pants & Trousers'
    WHEN UPPER(item_category) LIKE '%SUIT%' OR UPPER(item_category) LIKE '%JACKET%' THEN 'Suits & Jackets'
    WHEN UPPER(item_category) LIKE '%DRESS%' OR UPPER(item_category) LIKE '%GOWN%' THEN 'Dresses & Gowns'
    WHEN UPPER(item_category) LIKE '%COAT%' OR UPPER(item_category) LIKE '%OVERCOAT%' THEN 'Coats & Outerwear'
    WHEN UPPER(item_category) LIKE '%TIE%' OR UPPER(item_category) LIKE '%SCARF%' THEN 'Accessories'
    WHEN UPPER(item_category) LIKE '%CURTAIN%' OR UPPER(item_category) LIKE '%DRAPE%' THEN 'Home Items'
    WHEN UPPER(item_category) LIKE '%BLANKET%' OR UPPER(item_category) LIKE '%COMFORTER%' THEN 'Bedding'
    WHEN UPPER(item_category) LIKE '%ALTERATION%' OR UPPER(item_category) LIKE '%REPAIR%' THEN 'Services'
    ELSE 'Other'
  END as item_group,

  -- Service type classification
  CASE
    WHEN UPPER(item_type) LIKE '%DRY%CLEAN%' THEN 'Dry Cleaning'
    WHEN UPPER(item_type) LIKE '%LAUND%' OR UPPER(item_type) LIKE '%WASH%' THEN 'Laundering'
    WHEN UPPER(item_type) LIKE '%PRESS%' OR UPPER(item_type) LIKE '%IRON%' THEN 'Pressing'
    WHEN UPPER(item_type) LIKE '%STARCH%' THEN 'Starching'
    WHEN UPPER(item_type) LIKE '%SPOT%' THEN 'Spot Treatment'
    WHEN UPPER(item_type) LIKE '%ALTER%' THEN 'Alterations'
    WHEN UPPER(item_type) LIKE '%REPAIR%' THEN 'Repairs'
    ELSE 'Standard Service'
  END as service_type,

  -- Price tier
  CASE
    WHEN unit_price >= 20 THEN 'Premium'
    WHEN unit_price >= 10 THEN 'Standard'
    WHEN unit_price >= 5 THEN 'Economy'
    ELSE 'Budget'
  END as price_tier,

  -- Flags
  CASE WHEN order_frequency >= 100 THEN TRUE ELSE FALSE END as is_popular_item,
  CASE WHEN unit_price > avg_category_price * 1.5 THEN TRUE ELSE FALSE END as is_premium_priced,
  CASE WHEN popularity_rank_in_category <= 5 THEN TRUE ELSE FALSE END as is_top_5_in_category,

  -- Metadata
  CURRENT_TIMESTAMP() as created_at,
  CURRENT_TIMESTAMP() as updated_at

FROM item_metrics
ORDER BY item_category, item_type, unit_price;

-- Create views for common item groups
CREATE OR REPLACE VIEW `{project_id}.{dataset_name}.v_popular_items` AS
SELECT * FROM `{project_id}.{dataset_name}.dim_items`
WHERE is_popular_item = TRUE
ORDER BY overall_popularity_rank;

CREATE OR REPLACE VIEW `{project_id}.{dataset_name}.v_items_by_category` AS
SELECT
  item_category,
  item_group,
  COUNT(*) as item_count,
  AVG(standard_unit_price) as avg_price,
  SUM(total_quantity_sold) as total_sold
FROM `{project_id}.{dataset_name}.dim_items`
GROUP BY item_category, item_group
ORDER BY total_sold DESC;

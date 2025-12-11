-- Item Drops Breakdown
-- Analyzes dropped items by category and type
-- Parses the INV_ITEM field which contains encoded item data
--
-- INV_ITEM format: {qty}<A>{type}<B>{category}<C>{unit_price}<E>{total_price}
-- Multiple items separated by <Z>
--
-- Parameters:
--   @start_date: Start date (format: 'YYYY-MM-DD')
--   @end_date: End date (format: 'YYYY-MM-DD')

DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);
DECLARE end_date DATE DEFAULT CURRENT_DATE();

WITH raw_data AS (
    SELECT
        INV_NUM,
        ACCT_NUM,
        CUST_NAME,
        DATE_IN,
        INV_ITEM,
        TOT_ITEM
    FROM
        `${project_id}.${dataset_name}.claim`
    WHERE
        SAFE.PARSE_DATE('%Y%m%d', DATE_IN) BETWEEN start_date AND end_date
        AND DATE_IN IS NOT NULL
        AND INV_ITEM IS NOT NULL
),
split_items AS (
    SELECT
        INV_NUM,
        ACCT_NUM,
        CUST_NAME,
        item
    FROM
        raw_data,
        UNNEST(SPLIT(INV_ITEM, '<Z>')) AS item
    WHERE
        item != ''
),
decoded_items AS (
    SELECT
        INV_NUM,
        ACCT_NUM,
        CUST_NAME,
        item,
        -- Extract quantity: number before <A>
        REGEXP_EXTRACT(item, r'([0-9]+)<A>') AS item_qty,
        -- Extract type: between <A> and <B>
        REGEXP_EXTRACT(item, r'<A>([^<]+)') AS item_type,
        -- Extract category: between <B> and <C>
        REGEXP_EXTRACT(item, r'<B>([^<]+)') AS item_category,
        -- Extract unit price: between <C> and <E>
        REGEXP_EXTRACT(item, r'<C>([^<]+)') AS item_unit_price,
        -- Extract total price: after <E>
        REGEXP_EXTRACT(item, r'<E>([^<]+)') AS item_total_price
    FROM split_items
)

SELECT
    item_category AS item_category,
    item_type AS item_type,
    SUM(SAFE_CAST(item_qty AS FLOAT64)) AS total_quantity,
    SUM(SAFE_CAST(item_total_price AS FLOAT64)) AS total_price
FROM
    decoded_items
WHERE
    item_category IS NOT NULL
    AND item_type IS NOT NULL
GROUP BY
    1, 2
ORDER BY
    4 DESC

-- Order Drops vs Pickups Comparison
-- Compares orders dropped vs picked in a given period
--
-- Parameters:
--   @start_date: Start date (format: 'YYYY-MM-DD')
--   @end_date: End date (format: 'YYYY-MM-DD')

DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);
DECLARE end_date DATE DEFAULT CURRENT_DATE();

WITH dropped_orders AS (
    SELECT
        COUNT(*) AS number_of_orders,
        SUM(CAST(TOT_ITEM AS INT64)) AS total_items,
        SUM(CAST(SUB_TOT AS FLOAT64)) AS total_sales
    FROM
        `${project_id}.${dataset_name}.claim`
    WHERE
        SAFE.PARSE_DATE('%Y%m%d', DATE_IN) BETWEEN start_date AND end_date
        AND DATE_IN IS NOT NULL
),
picked_orders AS (
    SELECT
        COUNT(*) AS number_of_orders,
        SUM(CAST(TOT_ITEM AS INT64)) AS total_items,
        SUM(CAST(SUB_TOT AS FLOAT64)) AS total_sales
    FROM
        `${project_id}.${dataset_name}.invoice`
    WHERE
        SAFE.PARSE_DATE('%Y%m%d', DATE_PICK) BETWEEN start_date AND end_date
        AND DATE_PICK IS NOT NULL
)

SELECT 'Dropped' AS type, * FROM dropped_orders
UNION ALL
SELECT 'Picked' AS type, * FROM picked_orders

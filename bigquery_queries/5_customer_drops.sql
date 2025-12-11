-- Customer Drops Analysis
-- Shows customer activity during a period compared to their lifetime statistics
--
-- Parameters:
--   @start_date: Start date (format: 'YYYY-MM-DD')
--   @end_date: End date (format: 'YYYY-MM-DD')

DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);
DECLARE end_date DATE DEFAULT CURRENT_DATE();

WITH all_customer_details AS (
    SELECT
        ACCT_NUM,
        CUST_NAME,
        TEL_NUM,
        COUNT(*) AS number_of_visits,
        MIN(SAFE.PARSE_DATE('%Y%m%d', DATE_IN)) AS first_visit,
        MAX(SAFE.PARSE_DATE('%Y%m%d', DATE_IN)) AS last_visit,
        SUM(CAST(AMNT_DUE AS FLOAT64)) AS total_spend,
        SUM(CAST(TOT_ITEM AS INT64)) AS total_items
    FROM
        `${project_id}.${dataset_name}.claim`
    WHERE
        DATE_IN IS NOT NULL
    GROUP BY
        1, 2, 3
),
recent_cust_claims AS (
    SELECT
        ACCT_NUM,
        CUST_NAME,
        TEL_NUM,
        STRING_AGG(INV_NUM, ', ') AS recent_invoices,
        SUM(CAST(AMNT_DUE AS FLOAT64)) AS dropped_value,
        SUM(CAST(TOT_ITEM AS INT64)) AS dropped_items
    FROM
        `${project_id}.${dataset_name}.claim`
    WHERE
        SAFE.PARSE_DATE('%Y%m%d', DATE_IN) BETWEEN start_date AND end_date
        AND DATE_IN IS NOT NULL
    GROUP BY
        1, 2, 3
)

SELECT
    rc.ACCT_NUM AS account_number,
    rc.CUST_NAME AS customer_name,
    rc.TEL_NUM AS telephone_number,
    rc.recent_invoices AS recent_invoices,
    rc.dropped_value AS dropped_value,
    rc.dropped_items AS dropped_items,
    ac.number_of_visits AS total_visits,
    ac.first_visit AS first_visit,
    ac.last_visit AS last_visit,
    ac.total_items AS total_items_all_visits,
    ac.total_spend AS total_spend_all_visits
FROM
    recent_cust_claims AS rc
INNER JOIN
    all_customer_details AS ac
    ON rc.ACCT_NUM = ac.ACCT_NUM
ORDER BY
    ac.total_spend DESC

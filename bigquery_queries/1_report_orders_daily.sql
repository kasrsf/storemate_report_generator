-- Daily Order Statistics
-- Shows number of orders, average amount, and total amount by date
--
-- Parameters:
--   @start_date: Start date (format: 'YYYY-MM-DD')
--   @end_date: End date (format: 'YYYY-MM-DD')
--
-- Usage in Looker Studio:
--   Use date range filter to set @start_date and @end_date

DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);
DECLARE end_date DATE DEFAULT CURRENT_DATE();

SELECT
    FORMAT_DATE('%Y-%m-%d', PARSE_DATE('%Y%m%d', DATE_IN)) AS date,
    COUNT(*) AS num_orders,
    AVG(AMNT_DUE) AS average_amount,
    SUM(AMNT_DUE) AS total_amount
FROM
    `${project_id}.${dataset_name}.claim`
WHERE
    SAFE.PARSE_DATE('%Y%m%d', DATE_IN) BETWEEN start_date AND end_date
    AND DATE_IN IS NOT NULL
GROUP BY 1
ORDER BY 1

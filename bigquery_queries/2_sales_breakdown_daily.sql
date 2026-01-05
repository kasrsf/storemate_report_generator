-- Daily Sales Breakdown by Payment Method
-- Shows cash, debit, and credit card sales by date
--
-- Parameters:
--   @start_date: Start date (format: 'YYYY-MM-DD')
--   @end_date: End date (format: 'YYYY-MM-DD')

DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);
DECLARE end_date DATE DEFAULT CURRENT_DATE();

SELECT
    FORMAT_DATE('%Y-%m-%d', SAFE.PARSE_DATE('%Y%m%d', DATE_PICK)) AS date,
    COALESCE(SUM(CAST(CASH AS FLOAT64)), 0) AS cash,
    COALESCE(SUM(CAST(DEBIT AS FLOAT64)), 0) AS debit,
    COALESCE(SUM(CAST(VISA AS FLOAT64)), 0)
        + COALESCE(SUM(CAST(MCARD AS FLOAT64)), 0)
        + COALESCE(SUM(CAST(AMEX AS FLOAT64)), 0) AS credit
FROM
    `${project_id}.${dataset_name}.invoice`
WHERE
    SAFE.PARSE_DATE('%Y%m%d', DATE_PICK) BETWEEN start_date AND end_date
    AND DATE_PICK IS NOT NULL
GROUP BY 1
ORDER BY 1

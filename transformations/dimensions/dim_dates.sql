-- Dimension: Dates
-- Creates a date dimension table with calendar attributes
-- This enables easy time-based filtering and grouping

CREATE OR REPLACE TABLE `{project_id}.{dataset_name}.dim_dates` AS

WITH date_range AS (
  -- Get min and max dates from all date fields
  -- Handle both STRING and TIMESTAMP types
  SELECT
    MIN(CAST(DATE_IN AS DATE)) as min_date,
    MAX(COALESCE(CAST(DATE_PICK AS DATE), CAST(DATE_IN AS DATE))) as max_date
  FROM `{project_id}.{dataset_name}.claim`
),

all_dates AS (
  -- Generate date series from min to max date + 1 year buffer
  SELECT date
  FROM UNNEST(
    GENERATE_DATE_ARRAY(
      (SELECT DATE_SUB(min_date, INTERVAL 1 YEAR) FROM date_range),
      (SELECT DATE_ADD(max_date, INTERVAL 1 YEAR) FROM date_range)
    )
  ) AS date
)

SELECT
  -- Primary Key: YYYYMMDD format for easy joining
  FORMAT_DATE('%Y%m%d', date) AS date_key,

  -- Date value
  date AS date,

  -- Year attributes
  EXTRACT(YEAR FROM date) AS year,
  FORMAT_DATE('%Y', date) AS year_name,

  -- Quarter attributes
  EXTRACT(QUARTER FROM date) AS quarter,
  FORMAT_DATE('Q%Q %Y', date) AS quarter_name,

  -- Month attributes
  EXTRACT(MONTH FROM date) AS month,
  FORMAT_DATE('%B', date) AS month_name,
  FORMAT_DATE('%b', date) AS month_name_short,
  FORMAT_DATE('%Y-%m', date) AS year_month,

  -- Week attributes
  EXTRACT(WEEK FROM date) AS week_of_year,
  FORMAT_DATE('%Y-W%U', date) AS year_week,

  -- Day attributes
  EXTRACT(DAY FROM date) AS day_of_month,
  EXTRACT(DAYOFWEEK FROM date) AS day_of_week,  -- 1=Sunday, 7=Saturday
  FORMAT_DATE('%A', date) AS day_name,
  FORMAT_DATE('%a', date) AS day_name_short,
  EXTRACT(DAYOFYEAR FROM date) AS day_of_year,

  -- Flags
  CASE WHEN EXTRACT(DAYOFWEEK FROM date) IN (1, 7) THEN TRUE ELSE FALSE END AS is_weekend,
  CASE WHEN EXTRACT(DAYOFWEEK FROM date) BETWEEN 2 AND 6 THEN TRUE ELSE FALSE END AS is_weekday,

  -- Relative periods
  DATE_DIFF(date, CURRENT_DATE(), DAY) AS days_from_today,
  DATE_DIFF(date, DATE_TRUNC(CURRENT_DATE(), MONTH), DAY) AS days_from_month_start,
  DATE_DIFF(date, DATE_TRUNC(CURRENT_DATE(), YEAR), DAY) AS days_from_year_start,

  -- First/last day flags
  CASE WHEN EXTRACT(DAY FROM date) = 1 THEN TRUE ELSE FALSE END AS is_first_day_of_month,
  CASE WHEN date = LAST_DAY(date) THEN TRUE ELSE FALSE END AS is_last_day_of_month,

  -- Metadata
  CURRENT_TIMESTAMP() AS created_at,
  CURRENT_TIMESTAMP() AS updated_at

FROM all_dates
ORDER BY date;

-- Create indexes for better query performance
CREATE OR REPLACE VIEW `{project_id}.{dataset_name}.v_dim_dates_recent` AS
SELECT * FROM `{project_id}.{dataset_name}.dim_dates`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR);

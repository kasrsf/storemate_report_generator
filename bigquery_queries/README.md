# BigQuery SQL Queries for Looker Studio

This directory contains BigQuery-compatible SQL queries converted from the original DuckDB queries. These queries are optimized for use with Google Looker Studio dashboards.

## Query Files

| File | Description | Key Metrics |
|------|-------------|-------------|
| `1_report_orders_daily.sql` | Daily order statistics | Orders count, average amount, total sales |
| `2_sales_breakdown_daily.sql` | Daily sales by payment method | Cash, debit, credit card breakdown |
| `3_order_drops_pickups.sql` | Drops vs pickups comparison | Orders, items, and sales by type |
| `4_item_drops.sql` | Item-level analysis | Quantity and revenue by item category/type |
| `5_customer_drops.sql` | Customer behavior analysis | Recent activity vs lifetime statistics |

## Using in Looker Studio

### Method 1: Copy-Paste (Easiest)

1. Go to [Looker Studio](https://lookerstudio.google.com/)
2. Create a new report
3. Add a data source → BigQuery → Custom Query
4. Select your project and dataset
5. Copy the SQL from one of these files
6. **Replace placeholders**:
   - `${project_id}` → your GCP project ID (e.g., `my-project-123`)
   - `${dataset_name}` → your dataset name (e.g., `storemate_data`)
7. Modify the `DECLARE` statements for date ranges or remove them to use Looker's date range filter

### Method 2: Date Range Parameters (Recommended)

To use Looker Studio's built-in date range filter:

1. Remove the `DECLARE` statements from the query
2. Add date range parameters to the WHERE clause:

```sql
WHERE
    SAFE.PARSE_DATE('%Y%m%d', DATE_IN) BETWEEN @DS_START_DATE AND @DS_END_DATE
```

Looker Studio will automatically populate `@DS_START_DATE` and `@DS_END_DATE` from the date range filter widget.

### Method 3: Materialized Views (Best Performance)

For faster dashboard loading, create materialized views:

```sql
CREATE MATERIALIZED VIEW `your-project.storemate_data.mv_daily_orders` AS
SELECT
    FORMAT_DATE('%Y-%m-%d', SAFE.PARSE_DATE('%Y%m%d', DATE_IN)) AS date,
    COUNT(*) AS num_orders,
    AVG(AMNT_DUE) AS average_amount,
    SUM(AMNT_DUE) AS total_amount
FROM
    `your-project.storemate_data.claim`
WHERE
    DATE_IN IS NOT NULL
GROUP BY 1;
```

Then in Looker Studio, just query the materialized view instead of running the full query each time.

## Date Format Handling

The DBF files store dates in `YYYYMMDD` format (e.g., `20250107` for January 7, 2025). The queries use:

```sql
SAFE.PARSE_DATE('%Y%m%d', DATE_IN)
```

This safely converts the string to a DATE type. The `SAFE.` prefix prevents errors if invalid dates are encountered.

## Common Modifications

### Change Default Date Range

Edit the `DECLARE` statements:

```sql
-- Last 7 days
DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);
DECLARE end_date DATE DEFAULT CURRENT_DATE();

-- Last month
DECLARE start_date DATE DEFAULT DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH);
DECLARE end_date DATE DEFAULT DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 DAY);

-- Year to date
DECLARE start_date DATE DEFAULT DATE_TRUNC(CURRENT_DATE(), YEAR);
DECLARE end_date DATE DEFAULT CURRENT_DATE();
```

### Filter by Specific Store/Location

If you have multiple locations, add a filter:

```sql
WHERE
    SAFE.PARSE_DATE('%Y%m%d', DATE_IN) BETWEEN start_date AND end_date
    AND STORE_ID = 'MAIN_STORE'  -- Add your store filter
```

### Aggregate by Week or Month

Change the GROUP BY:

```sql
-- Weekly
SELECT
    FORMAT_DATE('%Y-W%U', SAFE.PARSE_DATE('%Y%m%d', DATE_IN)) AS week,
    ...

-- Monthly
SELECT
    FORMAT_DATE('%Y-%m', SAFE.PARSE_DATE('%Y%m%d', DATE_IN)) AS month,
    ...
```

## Testing Queries

Before using in Looker Studio, test in BigQuery Console:

1. Go to [BigQuery Console](https://console.cloud.google.com/bigquery)
2. Copy a query and replace placeholders
3. Click "RUN" to test
4. Verify results look correct
5. Then use in Looker Studio

## Optimization Tips

1. **Use Partitioned Tables**: If you have large datasets, partition by date:
   ```sql
   CREATE TABLE `project.dataset.claim_partitioned`
   PARTITION BY DATE(date_in_parsed)
   AS SELECT *, SAFE.PARSE_DATE('%Y%m%d', DATE_IN) as date_in_parsed
   FROM `project.dataset.claim`;
   ```

2. **Cache Results**: Enable query result caching in Looker Studio settings

3. **Use Aggregated Tables**: Pre-aggregate daily/weekly/monthly totals

4. **Limit Date Ranges**: Don't query years of data if you only need recent months

## Troubleshooting

### "Table not found" error
- Check that `${project_id}` and `${dataset_name}` are correct
- Verify tables exist: `bq ls your-project:storemate_data`

### "Invalid date" errors
- Some DATE_IN values might be malformed
- The queries use `SAFE.PARSE_DATE` to handle this
- Check source data: `SELECT DISTINCT DATE_IN FROM claim WHERE LENGTH(DATE_IN) != 8`

### Slow query performance
- Add WHERE clauses to limit date ranges
- Use materialized views for frequently accessed data
- Check query execution plan in BigQuery Console

### No data returned
- Verify ETL pipeline has run: `SELECT COUNT(*) FROM claim`
- Check date filters match your data range
- Verify field names match your schema

## Support

For issues with:
- **Queries**: Check BigQuery syntax documentation
- **Looker Studio**: Visit [Looker Studio Help](https://support.google.com/looker-studio)
- **ETL Pipeline**: Check Cloud Function logs

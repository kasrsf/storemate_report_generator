"""Data transformation module for dimensional model.

This module orchestrates the transformation of raw data into a dimensional
star schema for analytics.
"""

import logging
from pathlib import Path
from typing import Optional

from .bigquery_client import BigQueryClient
from .config import Config

logger = logging.getLogger(__name__)


class DataTransformations:
    """Orchestrates data transformations to build dimensional model."""

    def __init__(self, config: Optional[Config] = None):
        """Initialize transformations.

        Args:
            config: Application configuration. If None, uses default Config.
        """
        self.config = config or Config()
        # Use analytics dataset for dimensional model output
        self.bq_client = BigQueryClient(self.config, dataset_type="analytics")
        # Also create client for reading raw data
        self.raw_bq_client = BigQueryClient(self.config, dataset_type="raw")
        self.transformations_dir = Path(__file__).parent.parent.parent / "transformations"

    def _run_sql_file(self, sql_file: Path) -> None:
        """Execute a SQL file against BigQuery.

        Args:
            sql_file: Path to SQL file to execute
        """
        logger.info(f"Running transformation: {sql_file.name}")

        # Read SQL file
        sql = sql_file.read_text()

        # Replace placeholders with actual values
        sql = sql.replace("{project_id}", self.config.GCP_PROJECT_ID)
        sql = sql.replace("{raw_dataset}", self.config.GCP_RAW_DATASET)
        sql = sql.replace("{analytics_dataset}", self.config.GCP_ANALYTICS_DATASET)
        # Backward compatibility for old placeholder
        sql = sql.replace("{dataset_name}", self.config.GCP_ANALYTICS_DATASET)

        # Execute the SQL
        # BigQuery DDL statements don't return results, just execute
        query_job = self.bq_client.client.query(sql)
        query_job.result()  # Wait for completion

        logger.info(f"✓ Completed: {sql_file.name}")

    def run_all_transformations(self) -> dict[str, any]:
        """Run all transformations in correct dependency order.

        Returns:
            Dictionary with transformation results and timing.
        """
        import time
        start_time = time.time()

        results = {
            "start_time": start_time,
            "transformations_completed": [],
            "errors": [],
        }

        try:
            logger.info("=" * 60)
            logger.info("Starting dimensional model transformations")
            logger.info("=" * 60)

            # Step 1: Create dimensions (no dependencies)
            logger.info("\n[1/4] Creating dimension tables...")
            dimension_order = [
                "dim_dates.sql",
                "dim_customers.sql",
                "dim_items.sql",
                "dim_employees.sql",
            ]

            for dim_file in dimension_order:
                sql_file = self.transformations_dir / "dimensions" / dim_file
                if sql_file.exists():
                    self._run_sql_file(sql_file)
                    results["transformations_completed"].append(dim_file)
                else:
                    logger.warning(f"Dimension file not found: {dim_file}")

            # Step 2: Create fact tables (depend on dimensions)
            logger.info("\n[2/4] Creating fact tables...")
            fact_order = [
                "fact_orders.sql",
                "fact_order_items.sql",
            ]

            for fact_file in fact_order:
                sql_file = self.transformations_dir / "facts" / fact_file
                if sql_file.exists():
                    self._run_sql_file(sql_file)
                    results["transformations_completed"].append(fact_file)
                else:
                    logger.warning(f"Fact file not found: {fact_file}")

            # Step 3: Create aggregates (depend on fact tables)
            logger.info("\n[3/4] Creating aggregate tables...")
            aggregate_order = [
                "agg_daily_summary.sql",
                "agg_monthly_summary.sql",
            ]

            for agg_file in aggregate_order:
                sql_file = self.transformations_dir / "aggregates" / agg_file
                if sql_file.exists():
                    self._run_sql_file(sql_file)
                    results["transformations_completed"].append(agg_file)
                else:
                    logger.warning(f"Aggregate file not found: {agg_file}")

            # Step 4: Run data quality checks
            logger.info("\n[4/4] Running data quality checks...")
            self._run_data_quality_checks(results)

            logger.info("\n" + "=" * 60)
            logger.info("✓ All transformations completed successfully!")
            logger.info("=" * 60)

        except Exception as e:
            logger.error(f"Transformation error: {e}")
            results["errors"].append(str(e))
            raise

        finally:
            end_time = time.time()
            results["end_time"] = end_time
            results["duration_seconds"] = round(end_time - start_time, 2)

        return results

    def _run_data_quality_checks(self, results: dict) -> None:
        """Run basic data quality checks on transformed tables.

        Args:
            results: Results dictionary to append check results to
        """
        checks = []

        try:
            # Check 1: Verify row counts
            logger.info("  ↳ Checking row counts...")

            raw_count_query = f"""
                SELECT COUNT(*) as count
                FROM `{self.config.GCP_PROJECT_ID}.{self.config.GCP_RAW_DATASET}.claim`
            """
            raw_count = self.raw_bq_client.query(raw_count_query).iloc[0]['count']

            fact_count_query = f"""
                SELECT COUNT(*) as count
                FROM `{self.config.GCP_PROJECT_ID}.{self.config.GCP_ANALYTICS_DATASET}.fact_orders`
            """
            fact_count = self.bq_client.query(fact_count_query).iloc[0]['count']

            if raw_count == fact_count:
                logger.info(f"    ✓ Row count matches: {fact_count:,} orders")
                checks.append(("row_count_match", True))
            else:
                logger.warning(
                    f"    ⚠ Row count mismatch: raw={raw_count:,}, "
                    f"fact={fact_count:,}"
                )
                checks.append(("row_count_match", False))

            # Check 2: Verify revenue totals
            logger.info("  ↳ Checking revenue totals...")

            raw_revenue_query = f"""
                SELECT SUM(CAST(AMNT_DUE AS FLOAT64)) as total
                FROM `{self.config.GCP_PROJECT_ID}.{self.config.GCP_RAW_DATASET}.claim`
            """
            raw_revenue = self.raw_bq_client.query(raw_revenue_query).iloc[0]['total']

            fact_revenue_query = f"""
                SELECT SUM(amount_due) as total
                FROM `{self.config.GCP_PROJECT_ID}.{self.config.GCP_ANALYTICS_DATASET}.fact_orders`
            """
            fact_revenue = self.bq_client.query(fact_revenue_query).iloc[0]['total']

            revenue_diff_pct = abs(raw_revenue - fact_revenue) / raw_revenue * 100 if raw_revenue else 0

            if revenue_diff_pct < 0.01:  # Less than 0.01% difference
                logger.info(f"    ✓ Revenue matches: ${fact_revenue:,.2f}")
                checks.append(("revenue_match", True))
            else:
                logger.warning(
                    f"    ⚠ Revenue mismatch: raw=${raw_revenue:,.2f}, "
                    f"fact=${fact_revenue:,.2f} ({revenue_diff_pct:.2f}% diff)"
                )
                checks.append(("revenue_match", False))

            # Check 3: Check for null keys
            logger.info("  ↳ Checking for null foreign keys...")

            null_keys_query = f"""
                SELECT
                    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) as null_customers,
                    SUM(CASE WHEN date_in_key IS NULL THEN 1 ELSE 0 END) as null_dates
                FROM `{self.config.GCP_PROJECT_ID}.{self.config.GCP_ANALYTICS_DATASET}.fact_orders`
            """
            null_counts = self.bq_client.query(null_keys_query).iloc[0]

            if null_counts['null_customers'] == 0 and null_counts['null_dates'] == 0:
                logger.info("    ✓ No null foreign keys")
                checks.append(("no_null_keys", True))
            else:
                logger.warning(
                    f"    ⚠ Found null keys: customers={null_counts['null_customers']}, "
                    f"dates={null_counts['null_dates']}"
                )
                checks.append(("no_null_keys", False))

            # Check 4: Verify item explosion
            logger.info("  ↳ Checking item-level facts...")

            items_query = f"""
                SELECT COUNT(*) as count
                FROM `{self.config.GCP_PROJECT_ID}.{self.config.GCP_ANALYTICS_DATASET}.fact_order_items`
            """
            items_count = self.bq_client.query(items_query).iloc[0]['count']

            if items_count > fact_count:
                logger.info(f"    ✓ Items exploded: {items_count:,} line items from {fact_count:,} orders")
                checks.append(("items_exploded", True))
            else:
                logger.warning(f"    ⚠ Items not properly exploded: {items_count:,} items")
                checks.append(("items_exploded", False))

            results["data_quality_checks"] = checks
            passed = sum(1 for _, passed in checks if passed)
            total = len(checks)
            logger.info(f"\n  Data Quality: {passed}/{total} checks passed")

        except Exception as e:
            logger.error(f"Data quality check error: {e}")
            results["data_quality_checks"] = checks

    def refresh_specific_table(self, table_type: str, table_name: str) -> None:
        """Refresh a specific table.

        Args:
            table_type: Type of table ('dimensions', 'facts', 'aggregates')
            table_name: Name of SQL file (e.g., 'dim_customers.sql')
        """
        sql_file = self.transformations_dir / table_type / table_name

        if not sql_file.exists():
            raise FileNotFoundError(f"Transformation file not found: {sql_file}")

        logger.info(f"Refreshing {table_type}/{table_name}")
        self._run_sql_file(sql_file)
        logger.info(f"✓ Refreshed {table_name}")

    def get_table_stats(self) -> dict:
        """Get statistics about transformed tables.

        Returns:
            Dictionary with table names and row counts.
        """
        stats = {}

        tables = [
            "dim_dates",
            "dim_customers",
            "dim_items",
            "dim_employees",
            "fact_orders",
            "fact_order_items",
            "agg_daily_summary",
            "agg_monthly_summary",
        ]

        for table in tables:
            try:
                if self.bq_client.table_exists(table):
                    info = self.bq_client.get_table_info(table)
                    stats[table] = {
                        "rows": info["num_rows"],
                        "size_mb": round(info["num_bytes"] / (1024 * 1024), 2),
                        "created": info["created"],
                        "modified": info["modified"],
                    }
            except Exception as e:
                logger.warning(f"Could not get stats for {table}: {e}")

        return stats

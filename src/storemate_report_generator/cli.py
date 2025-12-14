import logging

import click

from .config import Config
from .database import Database
from .dbf_processor import process_all_dbf_files
from .etl_pipeline import ETLPipeline
from .reporting import ReportGenerator
from .utils import backup_data_directory

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)


@click.group()
def cli():
    """Storemate Report Generator CLI."""
    pass


@cli.command()
def process_data():
    """Process DBF files to CSV format."""
    config = Config()
    process_all_dbf_files(config)


@cli.command()
@click.option("--month", type=int, help="Month (1-12)", default=None)
@click.option("--year", type=int, help="Year (YYYY)", default=None)
def generate_reports(month, year):
    """Generate reports from processed data."""
    config = Config()
    db = Database(config)
    try:
        db.load_csv_files()
        generator = ReportGenerator(config, db)
        generator.generate_all_reports(month=month, year=year)
    finally:
        db.close()


@cli.command()
def backup_data():
    """Create a backup of the data directory."""
    config = Config()
    backup_data_directory(config)


@cli.command()
@click.option("--skip-dbf", is_flag=True, help="Skip DBF to CSV conversion")
@click.option("--skip-transform", is_flag=True, help="Skip dimensional model transformations")
def sync_to_bigquery(skip_dbf, skip_transform):
    """Sync data from local DBF files to BigQuery with dimensional model."""
    config = Config()

    # Validate GCP configuration
    if not config.GCP_PROJECT_ID:
        click.echo(
            "Error: GCP_PROJECT_ID not set. Please set the GCP_PROJECT_ID "
            "environment variable."
        )
        return

    pipeline = ETLPipeline(config)

    try:
        click.echo("Starting ETL pipeline to BigQuery...")
        results = pipeline.run_local_to_bigquery(
            skip_dbf_processing=skip_dbf,
            run_transformations=not skip_transform
        )

        click.echo("\n=== ETL Pipeline Results ===")
        click.echo(f"DBF files processed: {results.get('dbf_files_processed', 0)}")
        click.echo(f"CSV files created: {results.get('csv_files_created', 0)}")
        click.echo(f"Raw tables loaded: {results.get('tables_loaded', 0)}")

        if results.get("transformations_run"):
            click.echo(f"\n=== Dimensional Model ===")
            click.echo(f"Transformations completed: {len(results.get('transformations_completed', []))}")

            # Show data quality check results
            checks = results.get("data_quality_checks", [])
            if checks:
                passed = sum(1 for _, p in checks if p)
                click.echo(f"Data quality checks: {passed}/{len(checks)} passed")

        click.echo(f"\nTotal duration: {results.get('duration', 0):.2f} seconds")

        if results.get("errors"):
            click.echo(f"\n⚠ Errors encountered: {len(results['errors'])}")
            for error in results["errors"]:
                click.echo(f"  - {error}")
        else:
            click.echo("\n✓ Pipeline completed successfully!")

    except Exception as e:
        click.echo(f"Error: {str(e)}", err=True)
        raise


@cli.command()
def run_transformations():
    """Run dimensional model transformations on existing raw data."""
    config = Config()

    if not config.GCP_PROJECT_ID:
        click.echo(
            "Error: GCP_PROJECT_ID not set. Please set the GCP_PROJECT_ID "
            "environment variable."
        )
        return

    try:
        from .transformations import DataTransformations

        click.echo("Running dimensional model transformations...")
        transformer = DataTransformations(config)
        results = transformer.run_all_transformations()

        click.echo("\n=== Transformation Results ===")
        click.echo(f"Transformations completed: {len(results['transformations_completed'])}")

        for transform in results['transformations_completed']:
            click.echo(f"  ✓ {transform}")

        # Show data quality check results
        checks = results.get("data_quality_checks", [])
        if checks:
            click.echo(f"\n=== Data Quality Checks ===")
            for check_name, passed in checks:
                status = "✓" if passed else "✗"
                click.echo(f"  {status} {check_name}")

        click.echo(f"\nDuration: {results.get('duration_seconds', 0):.2f} seconds")

        if results.get("errors"):
            click.echo(f"\n⚠ Errors: {len(results['errors'])}")
            for error in results["errors"]:
                click.echo(f"  - {error}")
        else:
            click.echo("\n✓ Transformations completed successfully!")

    except Exception as e:
        click.echo(f"Error: {str(e)}", err=True)
        raise


@cli.command()
def show_table_stats():
    """Show statistics for dimensional model tables."""
    config = Config()

    if not config.GCP_PROJECT_ID:
        click.echo(
            "Error: GCP_PROJECT_ID not set. Please set the GCP_PROJECT_ID "
            "environment variable."
        )
        return

    try:
        from .transformations import DataTransformations

        transformer = DataTransformations(config)
        stats = transformer.get_table_stats()

        click.echo("\n=== BigQuery Table Statistics ===\n")

        if not stats:
            click.echo("No tables found. Run transformations first.")
            return

        # Print in categories
        click.echo("Dimensions:")
        for table_name in ["dim_dates", "dim_customers", "dim_items", "dim_employees"]:
            if table_name in stats:
                s = stats[table_name]
                click.echo(f"  {table_name:20s} {s['rows']:>10,} rows  {s['size_mb']:>8.2f} MB")

        click.echo("\nFacts:")
        for table_name in ["fact_orders", "fact_order_items"]:
            if table_name in stats:
                s = stats[table_name]
                click.echo(f"  {table_name:20s} {s['rows']:>10,} rows  {s['size_mb']:>8.2f} MB")

        click.echo("\nAggregates:")
        for table_name in ["agg_daily_summary", "agg_monthly_summary"]:
            if table_name in stats:
                s = stats[table_name]
                click.echo(f"  {table_name:20s} {s['rows']:>10,} rows  {s['size_mb']:>8.2f} MB")

        # Total
        total_rows = sum(s["rows"] for s in stats.values())
        total_size = sum(s["size_mb"] for s in stats.values())
        click.echo(f"\n{'Total':20s} {total_rows:>10,} rows  {total_size:>8.2f} MB")

    except Exception as e:
        click.echo(f"Error: {str(e)}", err=True)
        raise


@cli.command()
def init_gcp():
    """Initialize GCP resources (BigQuery dataset, GCS bucket)."""
    config = Config()

    # Validate GCP configuration
    if not config.GCP_PROJECT_ID:
        click.echo(
            "Error: GCP_PROJECT_ID not set. Please set the GCP_PROJECT_ID "
            "environment variable."
        )
        return

    try:
        from .bigquery_client import BigQueryClient
        from .gcs_client import GCSClient

        click.echo(f"Initializing GCP resources for project: {config.GCP_PROJECT_ID}")

        # Initialize BigQuery datasets
        click.echo("\n1. Setting up BigQuery datasets...")
        # Create raw dataset
        bq_raw_client = BigQueryClient(config, dataset_type="raw")
        raw_dataset = bq_raw_client.create_dataset()
        click.echo(f"   ✓ Raw dataset ready: {raw_dataset.dataset_id}")

        # Create analytics dataset
        bq_analytics_client = BigQueryClient(config, dataset_type="analytics")
        analytics_dataset = bq_analytics_client.create_dataset()
        click.echo(f"   ✓ Analytics dataset ready: {analytics_dataset.dataset_id}")

        # Initialize GCS bucket (if configured)
        if config.GCP_STORAGE_BUCKET:
            click.echo("\n2. Verifying GCS bucket...")
            try:
                gcs_client = GCSClient(config)
                click.echo(f"   ✓ Bucket accessible: {config.GCP_STORAGE_BUCKET}")
            except Exception as e:
                click.echo(f"   ! Bucket not accessible: {str(e)}")
                click.echo(
                    f"   You may need to create bucket: "
                    f"gs://{config.GCP_STORAGE_BUCKET}"
                )
        else:
            click.echo("\n2. GCS bucket not configured (optional)")

        click.echo("\n✓ GCP initialization complete!")

    except Exception as e:
        click.echo(f"Error: {str(e)}", err=True)
        raise


@cli.command()
def test_gcp():
    """Test GCP connectivity and configuration."""
    config = Config()

    click.echo("=== GCP Configuration Test ===\n")

    # Check environment variables
    click.echo("1. Environment Variables:")
    click.echo(f"   GCP_PROJECT_ID: {config.GCP_PROJECT_ID or '❌ Not set'}")
    click.echo(f"   GCP_RAW_DATASET: {config.GCP_RAW_DATASET}")
    click.echo(f"   GCP_ANALYTICS_DATASET: {config.GCP_ANALYTICS_DATASET}")
    click.echo(f"   GCP_LOCATION: {config.GCP_LOCATION}")
    click.echo(f"   GCP_STORAGE_BUCKET: {config.GCP_STORAGE_BUCKET or '(not set)'}")
    click.echo(
        f"   GCP_CREDENTIALS_PATH: {config.GCP_CREDENTIALS_PATH or '(using default)'}"
    )

    if not config.GCP_PROJECT_ID:
        click.echo("\n❌ GCP_PROJECT_ID is required. Cannot proceed with tests.")
        return

    # Test BigQuery connection
    click.echo("\n2. BigQuery Connection:")
    try:
        from .bigquery_client import BigQueryClient

        # Test raw dataset
        bq_raw_client = BigQueryClient(config, dataset_type="raw")
        click.echo(f"   ✓ Connected to project: {config.GCP_PROJECT_ID}")
        click.echo(f"   ✓ Raw dataset: {config.GCP_RAW_DATASET}")

        # Check if raw tables exist
        if bq_raw_client.table_exists(config.BQ_CLAIM_TABLE):
            info = bq_raw_client.get_table_info(config.BQ_CLAIM_TABLE)
            click.echo(f"     ✓ Sample raw table: {config.BQ_CLAIM_TABLE} ({info['num_rows']:,} rows)")
        else:
            click.echo(f"     ℹ No raw tables yet")

        # Test analytics dataset
        bq_analytics_client = BigQueryClient(config, dataset_type="analytics")
        click.echo(f"   ✓ Analytics dataset: {config.GCP_ANALYTICS_DATASET}")

        # Check if dimensional tables exist
        if bq_analytics_client.table_exists("fact_orders"):
            info = bq_analytics_client.get_table_info("fact_orders")
            click.echo(f"     ✓ Sample analytics table: fact_orders ({info['num_rows']:,} rows)")
        else:
            click.echo(f"     ℹ No analytics tables yet")

    except Exception as e:
        click.echo(f"   ❌ BigQuery error: {str(e)}")

    # Test GCS connection (if configured)
    if config.GCP_STORAGE_BUCKET:
        click.echo("\n3. Cloud Storage Connection:")
        try:
            from .gcs_client import GCSClient

            gcs_client = GCSClient(config)
            click.echo(f"   ✓ Connected to bucket: {config.GCP_STORAGE_BUCKET}")

            # List files
            blobs = gcs_client.list_blobs(prefix="")
            click.echo(f"   Files in bucket: {len(blobs)}")

        except Exception as e:
            click.echo(f"   ❌ GCS error: {str(e)}")

    click.echo("\n=== Test Complete ===")


if __name__ == "__main__":
    cli()

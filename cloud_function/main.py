"""Cloud Function for automated ETL pipeline.

This function can be triggered by:
1. Cloud Scheduler (HTTP trigger) - for scheduled runs
2. Cloud Storage (storage trigger) - when new DBF files are uploaded
"""

import logging
import os
from datetime import datetime
from pathlib import Path

import functions_framework
from google.cloud import storage

# Import our ETL pipeline
# Note: In Cloud Function, these imports work because we package the source code
from storemate_report_generator.bigquery_client import BigQueryClient
from storemate_report_generator.config import Config
from storemate_report_generator.dbf_processor import DBFProcessor

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


def process_dbf_files_from_gcs(config: Config) -> dict:
    """Download DBF files from GCS, process them, and load to BigQuery.

    Args:
        config: Application configuration

    Returns:
        Dictionary with processing results
    """
    results = {
        "start_time": datetime.now(),
        "files_processed": 0,
        "tables_loaded": 0,
        "errors": [],
    }

    try:
        # Initialize clients
        storage_client = storage.Client(project=config.GCP_PROJECT_ID)
        bucket = storage_client.bucket(config.GCP_STORAGE_BUCKET)
        bq_client = BigQueryClient(config)
        dbf_processor = DBFProcessor(config)

        # Create temp directories
        temp_dir = Path("/tmp/storemate_data")
        temp_dir.mkdir(parents=True, exist_ok=True)
        csv_dir = temp_dir / "csv"
        csv_dir.mkdir(exist_ok=True)

        # List and download DBF files from GCS
        logger.info(f"Listing DBF files in gs://{config.GCP_STORAGE_BUCKET}/data/")
        blobs = list(storage_client.list_blobs(
            bucket,
            prefix="data/",
            delimiter="/"
        ))

        dbf_blobs = [b for b in blobs if b.name.lower().endswith('.dbf')]
        logger.info(f"Found {len(dbf_blobs)} DBF files")

        # Download DBF files
        for blob in dbf_blobs:
            local_path = temp_dir / Path(blob.name).name
            logger.info(f"Downloading {blob.name}")
            blob.download_to_filename(str(local_path))
            results["files_processed"] += 1

        # Process DBF to CSV
        logger.info("Converting DBF files to CSV")
        dbf_results = dbf_processor.process_directory(temp_dir, csv_dir)

        if dbf_results["errors"]:
            results["errors"].extend(dbf_results["errors"])

        # Load CSVs to BigQuery
        logger.info("Loading data to BigQuery")
        bq_client.create_dataset()
        jobs = bq_client.load_all_csvs_from_directory(csv_dir)
        results["tables_loaded"] = len(jobs)

        logger.info(f"Successfully loaded {len(jobs)} tables to BigQuery")

    except Exception as e:
        logger.error(f"Error in ETL pipeline: {e}")
        results["errors"].append(str(e))
        raise

    finally:
        results["end_time"] = datetime.now()
        results["duration"] = (
            results["end_time"] - results["start_time"]
        ).total_seconds()

    return results


@functions_framework.http
def sync_data_http(request):
    """HTTP Cloud Function entry point (for Cloud Scheduler).

    Args:
        request: HTTP request object

    Returns:
        Response with processing results
    """
    try:
        logger.info("Starting scheduled ETL pipeline")

        config = Config()

        # Validate configuration
        if not config.GCP_PROJECT_ID:
            return {"error": "GCP_PROJECT_ID not configured"}, 500

        if not config.GCP_STORAGE_BUCKET:
            return {"error": "GCP_STORAGE_BUCKET not configured"}, 500

        # Run the ETL pipeline
        results = process_dbf_files_from_gcs(config)

        # Return results
        response = {
            "success": True,
            "timestamp": datetime.now().isoformat(),
            "files_processed": results["files_processed"],
            "tables_loaded": results["tables_loaded"],
            "duration_seconds": results["duration"],
            "errors": results["errors"],
        }

        logger.info(f"Pipeline completed: {response}")
        return response, 200

    except Exception as e:
        logger.error(f"Pipeline failed: {e}")
        return {"error": str(e), "success": False}, 500


@functions_framework.cloud_event
def sync_data_storage_trigger(cloud_event):
    """Cloud Storage trigger entry point (when files are uploaded).

    Triggered when a DBF file is uploaded to the GCS bucket.

    Args:
        cloud_event: CloudEvent object with GCS event data
    """
    try:
        # Extract event data
        data = cloud_event.data
        bucket_name = data["bucket"]
        file_name = data["name"]

        logger.info(
            f"File uploaded: gs://{bucket_name}/{file_name}"
        )

        # Only process DBF files
        if not file_name.lower().endswith('.dbf'):
            logger.info(f"Skipping non-DBF file: {file_name}")
            return

        # If this is a DBF file in the data/ folder, trigger full sync
        if file_name.startswith('data/'):
            logger.info("DBF file detected in data/ folder, triggering full sync")

            config = Config()
            results = process_dbf_files_from_gcs(config)

            logger.info(
                f"Sync completed: {results['tables_loaded']} tables loaded, "
                f"{results['duration']:.2f}s"
            )

    except Exception as e:
        logger.error(f"Storage trigger failed: {e}")
        raise


if __name__ == "__main__":
    # For local testing
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "test":
        logger.info("Running local test")

        class MockRequest:
            """Mock request for local testing."""
            pass

        response, status = sync_data_http(MockRequest())
        print(f"Status: {status}")
        print(f"Response: {response}")

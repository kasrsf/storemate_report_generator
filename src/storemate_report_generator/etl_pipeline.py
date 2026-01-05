"""ETL pipeline for syncing DBF data to BigQuery."""

import logging
from datetime import datetime
from pathlib import Path
from typing import Optional

from .bigquery_client import BigQueryClient
from .config import Config
from .dbf_processor import DBFProcessor
from .gcs_client import GCSClient
from .transformations import DataTransformations

logger = logging.getLogger(__name__)


class ETLPipeline:
    """Orchestrates the ETL pipeline from DBF files to BigQuery."""

    def __init__(self, config: Optional[Config] = None):
        """Initialize ETL pipeline.

        Args:
            config: Application configuration. If None, uses default Config.
        """
        self.config = config or Config()
        self.dbf_processor = DBFProcessor(self.config)
        self.bq_client = None
        self.gcs_client = None

        # Initialize GCP clients if configured
        if self.config.GCP_PROJECT_ID:
            try:
                self.bq_client = BigQueryClient(self.config)
                logger.info("BigQuery client initialized")
            except Exception as e:
                logger.warning(f"Could not initialize BigQuery client: {e}")

        if self.config.GCP_STORAGE_BUCKET:
            try:
                self.gcs_client = GCSClient(self.config)
                logger.info("GCS client initialized")
            except Exception as e:
                logger.warning(f"Could not initialize GCS client: {e}")

    def run_local_to_bigquery(
        self,
        skip_dbf_processing: bool = False,
        run_transformations: bool = True
    ) -> dict[str, any]:
        """Run the full ETL pipeline: DBF → CSV → BigQuery → Transformations.

        Args:
            skip_dbf_processing: If True, skip DBF to CSV conversion
                                (assumes CSVs already exist)
            run_transformations: If True, run dimensional model transformations
                                after loading raw data (default: True)

        Returns:
            Dictionary with pipeline results and statistics.
        """
        results = {
            "start_time": datetime.now(),
            "dbf_files_processed": 0,
            "csv_files_created": 0,
            "tables_loaded": 0,
            "transformations_run": False,
            "errors": [],
        }

        try:
            # Step 1: Process DBF files to CSV (if not skipped)
            if not skip_dbf_processing:
                logger.info("Step 1: Converting DBF files to CSV")
                dbf_results = self.dbf_processor.process_directory(
                    self.config.RAW_DATA_DIR, self.config.PROCESSED_DATA_DIR
                )
                results["dbf_files_processed"] = dbf_results["files_processed"]
                results["csv_files_created"] = dbf_results["files_created"]

                if dbf_results["errors"]:
                    results["errors"].extend(dbf_results["errors"])
            else:
                logger.info("Skipping DBF to CSV conversion")

            # Step 2: Upload CSVs to BigQuery (raw staging tables)
            if self.bq_client:
                logger.info("Step 2: Loading CSV files to BigQuery (raw dataset)")

                # Ensure raw dataset exists
                self.bq_client.create_dataset()

                # Load all CSV files to raw dataset
                jobs = self.bq_client.load_all_csvs_from_directory(
                    self.config.PROCESSED_DATA_DIR
                )
                results["tables_loaded"] = len(jobs)
                results["bq_jobs"] = jobs

                logger.info(f"Successfully loaded {len(jobs)} raw tables to {self.config.GCP_RAW_DATASET}")
            else:
                logger.warning("BigQuery client not available, skipping upload")

            # Step 3: Run dimensional model transformations
            if run_transformations and self.bq_client:
                logger.info("Step 3: Building dimensional model (analytics dataset)")
                transformer = DataTransformations(self.config)

                # Ensure analytics dataset exists before transformations
                transformer.bq_client.create_dataset()

                transform_results = transformer.run_all_transformations()

                results["transformations_run"] = True
                results["transformations_completed"] = transform_results["transformations_completed"]
                results["data_quality_checks"] = transform_results.get("data_quality_checks", [])

                if transform_results.get("errors"):
                    results["errors"].extend(transform_results["errors"])

            # Step 4: Optionally backup to GCS
            if self.gcs_client:
                logger.info("Step 4: Backing up CSV files to GCS")
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                gcs_prefix = f"backups/{timestamp}/"

                blobs = self.gcs_client.upload_directory(
                    self.config.PROCESSED_DATA_DIR, gcs_prefix
                )
                results["gcs_files_uploaded"] = len(blobs)
                logger.info(f"Backed up {len(blobs)} files to GCS")

        except Exception as e:
            logger.error(f"Pipeline error: {e}")
            results["errors"].append(str(e))
            raise

        finally:
            results["end_time"] = datetime.now()
            results["duration"] = (
                results["end_time"] - results["start_time"]
            ).total_seconds()

        return results

    def run_gcs_to_bigquery(self, gcs_prefix: str = "data/") -> dict[str, any]:
        """Run ETL pipeline from GCS to BigQuery.

        This is useful for Cloud Functions that are triggered by GCS uploads.

        Args:
            gcs_prefix: Prefix in GCS bucket where data files are stored

        Returns:
            Dictionary with pipeline results and statistics.
        """
        results = {
            "start_time": datetime.now(),
            "files_downloaded": 0,
            "tables_loaded": 0,
            "errors": [],
        }

        if not self.gcs_client:
            raise ValueError("GCS client not initialized")

        if not self.bq_client:
            raise ValueError("BigQuery client not initialized")

        try:
            # Step 1: Download files from GCS
            logger.info(f"Step 1: Downloading files from GCS (prefix: {gcs_prefix})")
            blobs = self.gcs_client.list_blobs(prefix=gcs_prefix)

            # Filter for DBF or CSV files
            data_blobs = [
                b for b in blobs
                if b.name.lower().endswith(('.dbf', '.csv'))
            ]

            # Create temp directory for downloads
            temp_dir = Path("/tmp/storemate_data")
            temp_dir.mkdir(parents=True, exist_ok=True)

            for blob in data_blobs:
                local_path = temp_dir / Path(blob.name).name
                self.gcs_client.download_file(blob.name, local_path)
                results["files_downloaded"] += 1

            # Step 2: Process DBF files if present
            dbf_files = list(temp_dir.glob("*.dbf"))
            if dbf_files:
                logger.info(f"Step 2: Processing {len(dbf_files)} DBF files")
                csv_dir = temp_dir / "csv"
                csv_dir.mkdir(exist_ok=True)

                dbf_results = self.dbf_processor.process_directory(temp_dir, csv_dir)
                results["dbf_files_processed"] = dbf_results["files_processed"]

                if dbf_results["errors"]:
                    results["errors"].extend(dbf_results["errors"])

                # Use CSV directory for BigQuery upload
                data_dir = csv_dir
            else:
                # Use temp directory (already has CSV files)
                data_dir = temp_dir

            # Step 3: Upload to BigQuery
            logger.info("Step 3: Loading data to BigQuery")
            self.bq_client.create_dataset()

            jobs = self.bq_client.load_all_csvs_from_directory(data_dir)
            results["tables_loaded"] = len(jobs)
            results["bq_jobs"] = jobs

            logger.info(f"Successfully loaded {len(jobs)} tables to BigQuery")

        except Exception as e:
            logger.error(f"Pipeline error: {e}")
            results["errors"].append(str(e))
            raise

        finally:
            results["end_time"] = datetime.now()
            results["duration"] = (
                results["end_time"] - results["start_time"]
            ).total_seconds()

        return results

    def sync_incremental(self) -> dict[str, any]:
        """Perform incremental sync (useful for real-time updates).

        This method can be extended to handle incremental updates
        based on timestamps or change detection.

        Returns:
            Dictionary with sync results.
        """
        # For now, this is the same as full sync
        # In the future, we could implement change detection
        logger.info("Running incremental sync (currently same as full sync)")
        return self.run_local_to_bigquery(skip_dbf_processing=False)

"""BigQuery client for managing data warehouse operations."""

import logging
from pathlib import Path
from typing import Optional

import pandas as pd
from google.cloud import bigquery
from google.cloud.exceptions import NotFound

from .config import Config

logger = logging.getLogger(__name__)


class BigQueryClient:
    """Client for managing BigQuery operations."""

    def __init__(self, config: Optional[Config] = None, dataset_type: str = "raw"):
        """Initialize BigQuery client.

        Args:
            config: Application configuration. If None, uses default Config.
            dataset_type: Which dataset to use ('raw' or 'analytics'). Default: 'raw'
        """
        self.config = config or Config()

        if not self.config.GCP_PROJECT_ID:
            raise ValueError(
                "GCP_PROJECT_ID not set. Please set the GCP_PROJECT_ID environment variable."
            )

        # Initialize BigQuery client
        self.client = bigquery.Client(
            project=self.config.GCP_PROJECT_ID,
            location=self.config.GCP_LOCATION,
        )

        # Set the dataset based on type
        self.dataset_type = dataset_type
        if dataset_type == "raw":
            self.dataset_name = self.config.GCP_RAW_DATASET
        elif dataset_type == "analytics":
            self.dataset_name = self.config.GCP_ANALYTICS_DATASET
        else:
            raise ValueError(f"Invalid dataset_type: {dataset_type}. Use 'raw' or 'analytics'")

        self.dataset_id = f"{self.config.GCP_PROJECT_ID}.{self.dataset_name}"
        logger.info(
            f"Initialized BigQuery client for project: {self.config.GCP_PROJECT_ID}, "
            f"dataset: {self.dataset_name} ({dataset_type})"
        )

    def create_dataset(self) -> bigquery.Dataset:
        """Create BigQuery dataset if it doesn't exist.

        Returns:
            The dataset object.
        """
        try:
            dataset = self.client.get_dataset(self.dataset_id)
            logger.info(f"Dataset {self.dataset_id} already exists")
            return dataset
        except NotFound:
            dataset = bigquery.Dataset(self.dataset_id)
            dataset.location = self.config.GCP_LOCATION

            # Set description based on dataset type
            if self.dataset_type == "raw":
                dataset.description = "StoreMate POS raw data - direct DBF file ingestion (staging layer)"
            else:
                dataset.description = "StoreMate POS analytics - dimensional model for reporting (consumption layer)"

            dataset = self.client.create_dataset(dataset, timeout=30)
            logger.info(f"Created dataset {self.dataset_id}")
            return dataset

    def load_dataframe_to_table(
        self,
        df: pd.DataFrame,
        table_name: str,
        write_disposition: str = "WRITE_TRUNCATE",
    ) -> bigquery.LoadJob:
        """Load a pandas DataFrame to a BigQuery table.

        Args:
            df: DataFrame to load
            table_name: Name of the table (without project/dataset prefix)
            write_disposition: How to write data. Options:
                - WRITE_TRUNCATE: Overwrite table (default)
                - WRITE_APPEND: Append to table
                - WRITE_EMPTY: Only write if table is empty

        Returns:
            The completed load job.
        """
        table_id = f"{self.dataset_id}.{table_name}"

        # Configure the load job
        job_config = bigquery.LoadJobConfig(
            write_disposition=write_disposition,
            autodetect=True,  # Auto-detect schema from DataFrame
        )

        logger.info(f"Loading {len(df)} rows to {table_id}")

        # Load data
        job = self.client.load_table_from_dataframe(df, table_id, job_config=job_config)

        # Wait for the job to complete
        job.result()

        # Get the updated table
        table = self.client.get_table(table_id)
        logger.info(
            f"Loaded {table.num_rows} rows to {table_id} "
            f"({table.num_bytes / (1024 * 1024):.2f} MB)"
        )

        return job

    def load_csv_to_table(
        self,
        csv_path: Path,
        table_name: str,
        write_disposition: str = "WRITE_TRUNCATE",
    ) -> bigquery.LoadJob:
        """Load a CSV file to a BigQuery table.

        Args:
            csv_path: Path to CSV file
            table_name: Name of the table (without project/dataset prefix)
            write_disposition: How to write data (WRITE_TRUNCATE, WRITE_APPEND, WRITE_EMPTY)

        Returns:
            The completed load job.
        """
        table_id = f"{self.dataset_id}.{table_name}"

        job_config = bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.CSV,
            skip_leading_rows=1,  # Skip header row
            autodetect=True,  # Auto-detect schema
            write_disposition=write_disposition,
        )

        logger.info(f"Loading CSV from {csv_path} to {table_id}")

        with open(csv_path, "rb") as source_file:
            job = self.client.load_table_from_file(source_file, table_id, job_config=job_config)

        # Wait for the job to complete
        job.result()

        # Get the updated table
        table = self.client.get_table(table_id)
        logger.info(
            f"Loaded {table.num_rows} rows to {table_id} "
            f"({table.num_bytes / (1024 * 1024):.2f} MB)"
        )

        return job

    def load_all_csvs_from_directory(
        self,
        directory: Path,
        write_disposition: str = "WRITE_TRUNCATE",
    ) -> dict[str, bigquery.LoadJob]:
        """Load all CSV files from a directory to BigQuery tables.

        Table names are derived from CSV filenames (without .csv extension).

        Args:
            directory: Directory containing CSV files
            write_disposition: How to write data (WRITE_TRUNCATE, WRITE_APPEND, WRITE_EMPTY)

        Returns:
            Dictionary mapping table names to their load jobs.
        """
        jobs = {}
        csv_files = list(directory.glob("*.csv"))

        if not csv_files:
            logger.warning(f"No CSV files found in {directory}")
            return jobs

        logger.info(f"Found {len(csv_files)} CSV files to load")

        for csv_path in csv_files:
            # Use filename without extension as table name
            table_name = csv_path.stem
            try:
                job = self.load_csv_to_table(csv_path, table_name, write_disposition)
                jobs[table_name] = job
            except Exception as e:
                logger.error(f"Failed to load {csv_path}: {e}")
                continue

        return jobs

    def query(self, sql: str) -> pd.DataFrame:
        """Execute a SQL query and return results as a DataFrame.

        Args:
            sql: SQL query to execute

        Returns:
            Query results as a pandas DataFrame.
        """
        logger.info(f"Executing query: {sql[:100]}...")
        query_job = self.client.query(sql)
        df = query_job.to_dataframe()
        logger.info(f"Query returned {len(df)} rows")
        return df

    def delete_table(self, table_name: str) -> None:
        """Delete a table if it exists.

        Args:
            table_name: Name of the table to delete
        """
        table_id = f"{self.dataset_id}.{table_name}"
        try:
            self.client.delete_table(table_id)
            logger.info(f"Deleted table {table_id}")
        except NotFound:
            logger.info(f"Table {table_id} not found, nothing to delete")

    def table_exists(self, table_name: str) -> bool:
        """Check if a table exists.

        Args:
            table_name: Name of the table to check

        Returns:
            True if table exists, False otherwise.
        """
        table_id = f"{self.dataset_id}.{table_name}"
        try:
            self.client.get_table(table_id)
            return True
        except NotFound:
            return False

    def get_table_info(self, table_name: str) -> dict:
        """Get information about a table.

        Args:
            table_name: Name of the table

        Returns:
            Dictionary with table metadata.
        """
        table_id = f"{self.dataset_id}.{table_name}"
        table = self.client.get_table(table_id)

        return {
            "table_id": table.table_id,
            "num_rows": table.num_rows,
            "num_bytes": table.num_bytes,
            "created": table.created,
            "modified": table.modified,
            "schema": [{"name": field.name, "type": field.field_type} for field in table.schema],
        }

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Config:
    """Application configuration."""

    # Local data directories
    RAW_DATA_DIR: Path = Path("data/raw")
    PROCESSED_DATA_DIR: Path = Path("data/processed")
    REPORTS_DIR: Path = Path("data/reports")
    QUERIES_DIR: Path = Path("data/queries")
    DB_FILE: Path = Path("data/processed/store.db")
    BACKUP_DIR: Path = Path("backups")

    # GCP Configuration
    GCP_PROJECT_ID: str = os.getenv("GCP_PROJECT_ID", "")
    GCP_DATASET_NAME: str = os.getenv("GCP_DATASET_NAME", "storemate_data")
    GCP_LOCATION: str = os.getenv("GCP_LOCATION", "US")  # BigQuery location
    GCP_STORAGE_BUCKET: str = os.getenv("GCP_STORAGE_BUCKET", "")
    GCP_CREDENTIALS_PATH: str = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")

    # BigQuery table names (will be created from DBF files)
    BQ_CLAIM_TABLE: str = "claim"
    BQ_INVOICE_TABLE: str = "invoice"
    BQ_CUSTOMER_TABLE: str = "custlist"
    BQ_EMPLOYEE_TABLE: str = "emplist"
    BQ_ITEM_TABLE: str = "pricelist"

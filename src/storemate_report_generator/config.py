import os
from dataclasses import dataclass
from pathlib import Path

# Try to load .env file if it exists
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # python-dotenv not installed, use system env vars


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
    GCP_RAW_DATASET: str = os.getenv("GCP_RAW_DATASET", "storemate_raw")
    GCP_ANALYTICS_DATASET: str = os.getenv("GCP_ANALYTICS_DATASET", "storemate_analytics")
    GCP_LOCATION: str = os.getenv("GCP_LOCATION", "US")  # BigQuery location
    GCP_STORAGE_BUCKET: str = os.getenv("GCP_STORAGE_BUCKET", "")
    GCP_CREDENTIALS_PATH: str = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")

    # Backward compatibility: if old GCP_DATASET_NAME is set, use it for both
    def __post_init__(self):
        """Handle backward compatibility for dataset configuration."""
        legacy_dataset = os.getenv("GCP_DATASET_NAME")
        if legacy_dataset and not os.getenv("GCP_RAW_DATASET"):
            object.__setattr__(self, "GCP_RAW_DATASET", legacy_dataset)
        if legacy_dataset and not os.getenv("GCP_ANALYTICS_DATASET"):
            object.__setattr__(self, "GCP_ANALYTICS_DATASET", legacy_dataset)

    # BigQuery table names (will be created from DBF files)
    BQ_CLAIM_TABLE: str = "claim"
    BQ_INVOICE_TABLE: str = "invoice"
    BQ_CUSTOMER_TABLE: str = "custlist"
    BQ_EMPLOYEE_TABLE: str = "emplist"
    BQ_ITEM_TABLE: str = "pricelist"

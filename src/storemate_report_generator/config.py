from dataclasses import dataclass
from pathlib import Path


@dataclass
class Config:
    """Application configuration."""

    RAW_DATA_DIR: Path = Path("data/raw")
    PROCESSED_DATA_DIR: Path = Path("data/processed")
    REPORTS_DIR: Path = Path("data/reports")
    QUERIES_DIR: Path = Path("data/queries")
    DB_FILE: Path = Path("data/processed/store.db")
    BACKUP_DIR: Path = Path("backups")

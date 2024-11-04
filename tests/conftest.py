import shutil

import pandas as pd
import pytest

from storemate_report_generator.config import Config


@pytest.fixture
def temp_dir(tmp_path):
    """Create a temporary direcotry structure for testing."""
    data_dir = tmp_path / "data"
    for subdir in ["raw", "processed", "reports"]:
        (data_dir / subdir).mkdir(parents=True)
    (tmp_path / "reports" / "queries").mkdir(parents=True)
    (tmp_path / "backups").mkdir()

    yield tmp_path
    # cleanup
    shutil.rmtree(tmp_path)


@pytest.fixture
def test_config(temp_dir):
    """Create a test configuration."""

    class TestConfig(Config):
        def __init__(self, base_dir):
            self.RAW_DATA_DIR = base_dir / "data/raw"
            self.PROCESSED_DATA_DIR = base_dir / "data/processed"
            self.REPORTS_DIR = base_dir / "data/reports"
            self.QUERIES_DIR = base_dir / "reports/queries"
            self.DB_FILE = base_dir / "data/processed/store.db"
            self.BACKUP_DIR = base_dir / "backups"

    return TestConfig(temp_dir)


@pytest.fixture
def sample_dbf_file(temp_dir):
    """Create a sample DBF file for testing."""
    # Since we can't easily create a DBF file, we'll mock the DBF reading
    dbf_path = temp_dir / "data/raw/sample.dbf"
    dbf_path.touch()
    return dbf_path


@pytest.fixture
def sample_csv_data():
    """Create sample CSV data for testing"""
    return pd.DataFrame(
        {
            "customer_name": ["John Doe", "Jane Smith"],
            "item_name": ["Item A", "Item B"],
            "quantity": [2, 3],
            "amount": [100.0, 150.0],
            "date": ["2024-01-01", "2024-01-02"],
        }
    )


@pytest.fixture
def sample_query_file(temp_dir):
    """Create a sample query file for testing."""
    query_content = """
        name: test_report
        description: "Test report"
        query: |
            SELECT * FROM test_table
            WHERE amount > 100
        output_file: test_report.xlsx
    """
    query_file = temp_dir / "reports/queries/test_report.yaml"
    query_file.write_text(query_content)
    return query_file

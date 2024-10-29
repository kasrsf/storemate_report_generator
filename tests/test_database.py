import pandas as pd
import pytest

from storemate_report_generator.database import Database


def test_database_initialization(test_config):
    db = Database(test_config)
    try:
        # Verify file_mapping table exists
        result = db.conn.execute("SELECT * FROM file_mapping").fetchall()
        assert isinstance(result, list)
    finally:
        db.close()


def test_load_csv_files(test_config, sample_csv_data):
    # Create test CSV file
    csv_path = test_config.PROCESSED_DATA_DIR / "test.csv"
    sample_csv_data.to_csv(csv_path, index=False)

    db = Database(test_config)
    try:
        db.load_csv_files()

        # Verify table creation
        result = db.conn.execute("SELECT * FROM test").df()
        # Ensure date columns have the same type
        result["date"] = pd.to_datetime(result["date"]).astype("datetime64[us]")
        sample_csv_data["date"] = pd.to_datetime(sample_csv_data["date"]).astype("datetime64[us]")

        pd.testing.assert_frame_equal(
            result.sort_values("customer_name").reset_index(drop=True),
            sample_csv_data.sort_values("customer_name").reset_index(drop=True),
        )

        # Verify mapping
        mapping = db.conn.execute("SELECT * FROM file_mapping").df()
        assert len(mapping) == 1
        assert mapping["table_name"].iloc[0] == "test"
    finally:
        db.close()


def test_execute_query(test_config, sample_csv_data):
    db = Database(test_config)
    try:
        # Create test table
        db.conn.register("sample_data", sample_csv_data)
        db.conn.execute("CREATE TABLE test AS SELECT * FROM sample_data")

        # Test query execution
        query = "SELECT COUNT(*) as count FROM test"
        result = db.execute_query(query)
        assert result["count"].iloc[0] == len(sample_csv_data)
    finally:
        db.close()


def test_database_error_handling(test_config):
    db = Database(test_config)
    try:
        with pytest.raises(Exception):
            db.execute_query("SELECT * FROM nonexistent_table")
    finally:
        db.close()

from unittest.mock import patch

import pandas as pd

from storemate_report_generator.database import Database
from storemate_report_generator.reporting import ReportGenerator


def test_load_query(test_config, sample_query_file):
    db = Database(test_config)
    generator = ReportGenerator(test_config, db)

    try:
        query_config = generator.load_query(sample_query_file)
        assert query_config["name"] == "test_report"
        assert "query" in query_config
        assert "output_file" in query_config
    finally:
        db.close()


def test_generate_report(test_config, sample_query_file, sample_csv_data):
    db = Database(test_config)
    try:
        # Setup test data
        db.conn.register("sample_data", sample_csv_data)
        db.conn.execute("CREATE TABLE test_table AS SELECT * FROM sample_data")

        generator = ReportGenerator(test_config, db)
        generator.generate_report(sample_query_file)

        # Verify report file was created
        report_file = test_config.REPORTS_DIR / "test_report.csv"
        assert report_file.exists()

        # Verify report content
        report_data = pd.read_csv(report_file)
        assert len(report_data) == len(sample_csv_data[sample_csv_data["amount"] > 100])
    finally:
        db.close()


def test_generate_all_reports(test_config, sample_query_file):
    # Create multiple query files
    for i in range(3):
        query_file = test_config.QUERIES_DIR / f"test_report_{i}.yaml"
        query_file.write_text(sample_query_file.read_text())

    db = Database(test_config)
    try:
        generator = ReportGenerator(test_config, db)

        with patch.object(generator, "generate_report") as mock_generate:
            generator.generate_all_reports()
            assert mock_generate.call_count == 4  # 3 test files + 1 sampel file
    finally:
        db.close()

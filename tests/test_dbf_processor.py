from unittest.mock import patch

import pandas as pd
import pytest

from storemate_report_generator.dbf_processor import process_all_dbf_files, process_dbf_file


def test_process_dbf_file(sample_dbf_file, temp_dir, sample_csv_data):
    output_path = temp_dir / "data/processed/sample.csv"

    # Mock DBF reading
    with patch("storemate_report_generator.dbf_processor.DBF") as mock_dbf:
        mock_dbf.return_value = [
            dict(zip(sample_csv_data.columns, row)) for row in sample_csv_data.values
        ]

        process_dbf_file(sample_dbf_file, output_path)

        # Verify file was created
        assert output_path.exists()
        # Verify content
        result_df = pd.read_csv(output_path)
        pd.testing.assert_frame_equal(result_df, sample_csv_data)


def test_process_dbf_file_error(sample_dbf_file, temp_dir):
    output_path = temp_dir / "data/processed/sample.csv"

    # Mock DBF reading with error
    with patch("storemate_report_generator.dbf_processor.DBF", side_effect=Exception("Test error")):
        with pytest.raises(Exception, match="Test error"):
            process_dbf_file(sample_dbf_file, output_path)


def test_process_all_dbf_files(test_config, sample_dbf_file):
    # Create multiple test DBF files
    for i in range(3):
        (test_config.RAW_DATA_DIR / f"test{i}.dbf").touch()

    with patch("storemate_report_generator.dbf_processor.process_dbf_file") as mock_process:
        process_all_dbf_files(test_config)

        # Verify process_dbf_file was called for each DBF file
        assert mock_process.call_count == 4  # 3 test files + 1 sample file

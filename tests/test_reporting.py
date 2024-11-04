from unittest.mock import MagicMock, Mock, patch

import pytest

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


def test_init_excel_writer(test_config):
    db = Database(test_config)
    generator = ReportGenerator(test_config, db)
    try:
        with patch("pandas.ExcelWriter", autospec=True) as mock_writer_class:
            mock_writer = mock_writer_class.return_value
            mock_writer.__enter__.return_value = mock_writer
            # Initialize Excel writer
            generator._init_excel_writer()
            # Verify ExcelWriter was called with correct parameters
            mock_writer_class.assert_called_once_with(generator.excel_file, engine="openpyxl")
            assert generator.excel_writer is not None
            assert generator.excel_file.suffix == ".xlsx"
            assert generator.excel_file.parent == test_config.REPORTS_DIR
    finally:
        generator.close()
        db.close()


def test_generate_report(test_config, sample_query_file, sample_csv_data):
    db = Database(test_config)
    try:
        # Setup test data
        db.conn.register("sample_data", sample_csv_data)
        db.conn.execute("CREATE TABLE test_table AS SELECT * FROM sample_data")

        generator = ReportGenerator(test_config, db)

        with patch("pandas.ExcelWriter", autospec=True) as mock_writer_class:
            mock_writer = mock_writer_class.return_value
            mock_writer.__enter__.return_value = mock_writer
            # Use a real dict for sheets
            mock_writer.sheets = {}

            with patch("pandas.DataFrame.to_excel") as mock_to_excel:
                # Define side effect to add the sheet to the sheets dict
                def to_excel_side_effect(excel_writer, sheet_name, index=False):
                    mock_writer.sheets[sheet_name] = MagicMock(sheet_state="visible")

                mock_to_excel.side_effect = to_excel_side_effect

                generator.generate_report(sample_query_file)

                # Verify ExcelWriter was initialized
                mock_writer_class.assert_called_once_with(generator.excel_file, engine="openpyxl")

                # Verify to_excel was called once
                mock_to_excel.assert_called_once_with(
                    mock_writer, sheet_name="test_report", index=False
                )

                # Verify the sheet was added and is visible
                assert "test_report" in mock_writer.sheets
                assert mock_writer.sheets["test_report"].sheet_state == "visible"
    finally:
        generator.close()
        db.close()


# def test_multiple_sheets_in_excel(test_config, sample_query_file, sample_csv_data):
#     db = Database(test_config)
#     try:
#         # Setup test data
#         db.conn.register("sample_data", sample_csv_data)
#         db.conn.execute("CREATE TABLE test_table AS SELECT * FROM sample_csv_data")

#         generator = ReportGenerator(test_config, db)

#         with patch('pandas.ExcelWriter', autospec=True) as mock_writer_class:
#             mock_writer = mock_writer_class.return_value
#             mock_writer.__enter__.return_value = mock_writer
#             # Use a real dict for sheets
#             mock_writer.sheets = {}

#             with patch('pandas.DataFrame.to_excel') as mock_to_excel:
#                 # Define side effect to add sheets
#                 def to_excel_side_effect(excel_writer, sheet_name, index=False):
#                     mock_writer.sheets[sheet_name] = MagicMock(sheet_state='visible')

#                 mock_to_excel.side_effect = to_excel_side_effect

#                 # Create and generate multiple reports
#                 for i in range(3):
#                     query_file = test_config.QUERIES_DIR / f"test_report_{i}.yaml"
#                     query_file.write_text(sample_query_file.read_text())
#                     generator.generate_report(query_file)

#                 # Verify ExcelWriter was initialized once
#                 mock_writer_class.assert_called_once_with(generator.excel_file, engine='openpyxl')

#                 # Verify to_excel was called three times
#                 assert mock_to_excel.call_count == 3

#                 # Verify all sheets were added and are visible
#                 for i in range(3):
#                     sheet_name = f"test_report_{i}"
#                     assert sheet_name in mock_writer.sheets
#                     assert mock_writer.sheets[sheet_name].sheet_state == 'visible'
#     finally:
#         generator.close()
#         db.close()


# def test_column_width_adjustment(test_config):
#     db = Database(test_config)
#     generator = ReportGenerator(test_config, db)
#     try:
#         df = pd.DataFrame({
#             'short': ['a', 'b'],
#             'long_column': ['very long text here', 'another long text']
#         })

#         mock_worksheet = MagicMock()
#         mock_worksheet.column_dimensions = {}

#         generator._adjust_column_widths(mock_worksheet, df)

#         # Verify column_dimensions was accessed and set correctly
#         assert 'A' in mock_worksheet.column_dimensions
#         assert 'B' in mock_worksheet.column_dimensions
#         # Verify width was set correctly
#         assert mock_worksheet.column_dimensions['A'].width == 5  # 'short' (5 chars) + 2
#         assert mock_worksheet.column_dimensions['B'].width == 14  # 'long_column' (12 chars) + 2
#     finally:
#         generator.close()
#         db.close()


def test_excel_writer_cleanup(test_config):
    db = Database(test_config)
    generator = ReportGenerator(test_config, db)
    try:
        generator._init_excel_writer()
        with patch.object(generator.excel_writer, "close") as mock_close:
            generator.close()
            mock_close.assert_called_once()
    finally:
        db.close()


def test_generate_report_error_handling(test_config, sample_query_file):
    db = Database(test_config)
    generator = ReportGenerator(test_config, db)
    try:
        with patch("pandas.ExcelWriter", autospec=True) as mock_writer_class:
            mock_writer = mock_writer_class.return_value
            mock_writer.__enter__.return_value = mock_writer
            mock_writer.sheets = {}

            with patch("pandas.DataFrame.to_excel") as mock_to_excel:
                # Define side effect to add sheet
                def to_excel_side_effect(excel_writer, sheet_name, index=False):
                    mock_writer.sheets[sheet_name] = MagicMock(sheet_state="visible")

                mock_to_excel.side_effect = to_excel_side_effect

                # Simulate database error
                db.execute_query = Mock(side_effect=Exception("Database error"))

                with pytest.raises(Exception, match="Database error"):
                    generator.generate_report(sample_query_file)

                # Verify to_excel was not called due to exception
                mock_to_excel.assert_not_called()
    finally:
        generator.close()
        db.close()

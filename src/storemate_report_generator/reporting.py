import logging
from calendar import monthrange
from datetime import datetime
from pathlib import Path
from typing import Any

import pandas as pd
import yaml

from .config import Config
from .database import Database

logger = logging.getLogger(__name__)


class ReportGenerator:
    def __init__(self, config: Config, db: Database):
        self.config = config
        self.db = db
        self.excel_file = None
        self.excel_writer = None

    def load_query(self, query_file: Path) -> dict[str, Any]:
        """Load query configuration from YAML file."""
        with open(query_file) as f:
            return yaml.safe_load(f)

    def _init_excel_writer(self):
        """Initialize Excel writer with timestamped filename."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.excel_file = self.config.REPORTS_DIR / f"reports_{timestamp}.xlsx"
        self.excel_file.parent.mkdir(parents=True, exist_ok=True)
        self.excel_writer = pd.ExcelWriter(self.excel_file, engine="openpyxl")

    def _adjust_column_widths(self, worksheet, df):
        """Adjust column widths to fit content."""
        for idx, col in enumerate(df.columns):
            # Calculate max length of column
            max_length = max(df[col].astype(str).apply(len).max(), len(str(col)))
            adjusted_width = max_length + 2  # Add padding
            # Convert to Excel column letter
            column_letter = (
                chr(65 + idx) if idx < 26 else chr(64 + idx // 26) + chr(65 + (idx % 26))
            )
            worksheet.column_dimensions[column_letter].width = adjusted_width

    def _prepare_query(self, query: str, month: int = None, year: int = None) -> str:
        """Replace variables in the query with actual values."""

        # Use current date if month or year not provided
        current_date = datetime.now()
        month = month or current_date.month
        year = year or current_date.year

        # Create a dictionary of variables to replace
        variables = {
            "YEAR": str(year),
            "MONTH": str(month).zfill(2),  # Pad with zero if needed
            "FIRST_DAY": f"{year}-{str(month).zfill(2)}-01",
            "LAST_DAY": f"{year}-{str(month).zfill(2)}-{str(self._get_last_day_of_month(year, month)).zfill(2)}",
        }

        # Replace each variable in the query
        prepared_query = query
        for var_name, var_value in variables.items():
            prepared_query = prepared_query.replace(f"${var_name}", var_value)

        return prepared_query

    def _get_last_day_of_month(self, year: int, month: int) -> int:
        """Get the last day of the given month."""
        return monthrange(year, month)[1]

    def generate_report(self, query_file: Path, month: int = None, year: int = None) -> None:
        """Generate a single report as a sheet in Excel file."""
        try:
            # Initialize Excel writer if not exists
            if self.excel_writer is None:
                self._init_excel_writer()

            query_config = self.load_query(query_file)
            # Replace variables in the query
            query = self._prepare_query(query_config["query"], month, year)
            sheet_name = Path(query_config["output_file"]).stem[
                :31
            ]  # Use filename without extension as sheet name and truncate to 31 characters

            # Execute query and save results to Excel sheet
            try:
                results = self.db.execute_query(query)
            except Exception:
                breakpoint()
            results.to_excel(self.excel_writer, sheet_name=sheet_name, index=False)

            # Adjust column widths
            worksheet = self.excel_writer.sheets[sheet_name]
            self._adjust_column_widths(worksheet, results)

            logger.info(f"Added sheet {sheet_name} to {self.excel_file}")
        except Exception as e:
            logger.error(f"Error generating report from {
                         query_file}: {str(e)}")
            raise

    def generate_all_reports(self, month: int = None, year: int = None) -> None:
        """Generate all reports from query files."""
        try:
            for query_file in sorted(self.config.QUERIES_DIR.glob("*.yaml")):
                self.generate_report(query_file, month, year)
        finally:
            self.close()

    def close(self):
        """Save and close Excel writer."""
        try:
            if self.excel_writer is not None:
                self.excel_writer.close()
                logger.info(f"Saved Excel report to {self.excel_file}")
        except Exception as e:
            logger.error(f"Error saving Excel file: {str(e)}")
            raise

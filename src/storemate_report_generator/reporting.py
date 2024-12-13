import logging
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

    def generate_report(self, query_file: Path) -> None:
        """Generate a single report as a sheet in Excel file."""
        try:
            # Initialize Excel writer if not exists
            if self.excel_writer is None:
                self._init_excel_writer()

            query_config = self.load_query(query_file)
            query = query_config["query"]
            sheet_name = Path(query_config["output_file"]).stem[
                :31
            ]  # Use filename without extension as sheet name and truncate to 31 characters

            # Execute query and save results to Excel sheet
            results = self.db.execute_query(query)
            results.to_excel(self.excel_writer, sheet_name=sheet_name, index=False)

            # Adjust column widths
            worksheet = self.excel_writer.sheets[sheet_name]
            self._adjust_column_widths(worksheet, results)

            logger.info(f"Added sheet {sheet_name} to {self.excel_file}")
        except Exception as e:
            logger.error(f"Error generating report from {query_file}: {str(e)}")
            raise

    def generate_all_reports(self) -> None:
        """Generate all reports from query files."""
        try:
            for query_file in sorted(self.config.QUERIES_DIR.glob("*.yaml")):
                self.generate_report(query_file)
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

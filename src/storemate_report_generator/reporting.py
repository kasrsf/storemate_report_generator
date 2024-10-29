import logging
from pathlib import Path
from typing import Any

import yaml

from .config import Config
from .database import Database

logger = logging.getLogger(__name__)


class ReportGenerator:
    def __init__(self, config: Config, db: Database):
        self.config = config
        self.db = db

    def load_query(self, query_file: Path) -> dict[str, Any]:
        """Load query configuration from YAML file."""
        with open(query_file) as f:
            return yaml.safe_load(f)

    def generate_report(self, query_file: Path) -> None:
        """Generate a single report from a query file."""
        try:
            query_config = self.load_query(query_file)
            query = query_config["query"]
            output_file = self.config.REPORTS_DIR / query_config["output_file"]

            # Execute query and save results
            results = self.db.execute_query(query)
            output_file.parent.mkdir(parents=True, exist_ok=True)
            results.to_csv(output_file, index=False)

            logger.info(f"Generated report {output_file}")
        except Exception as e:
            logger.error(f"Error generating report from {query_file}: {str(e)}")
            raise

    def generate_all_reports(self) -> None:
        """Generate all reports from query files."""
        for query_file in self.config.QUERIES_DIR.glob("*.yaml"):
            self.generate_report(query_file)

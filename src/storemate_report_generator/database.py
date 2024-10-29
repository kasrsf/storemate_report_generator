import logging

import duckdb
import pandas as pd

from .config import Config

logger = logging.getLogger(__name__)


class Database:
    def __init__(self, config: Config):
        self.config = config
        self.conn = duckdb.connect(str(config.DB_FILE))
        self._init_db()

    def _init_db(self) -> None:
        """Initialize database with file mapping table."""
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS file_mapping (
                filename VARCHAR,
                table_name VARCHAR,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

    def load_csv_files(self) -> None:
        """Load all CSV files from processed directory into DuckDB."""
        for csv_file in self.config.PROCESSED_DATA_DIR.glob("*.csv"):
            table_name = csv_file.stem
            try:
                # Create table from CSV
                self.conn.execute(f"DROP TABLE IF EXISTS {table_name}")
                self.conn.execute(
                    f"CREATE TABLE {table_name} AS SELECT * FROM read_csv_auto('{csv_file}')"  # noqa: S608
                )

                # Update mapping
                self.conn.execute(
                    """
                    INSERT INTO file_mapping (filename, table_name)
                    VALUES (?, ?)
                """,
                    [str(csv_file), table_name],
                )

                logger.info(f"Loaded {csv_file} into table {table_name}")
            except Exception as e:
                logger.error(f"Error loading {csv_file}: {str(e)}")
                raise

    def execute_query(self, query: str) -> pd.DataFrame:
        """Execute a SQL query and return results as a DataFrame."""
        return self.conn.execute(query).df()

    def close(self) -> None:
        """Close database connection."""
        self.conn.close()

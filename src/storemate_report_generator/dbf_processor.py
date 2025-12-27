import logging
from pathlib import Path
from typing import Optional

import pandas as pd
from dbfread import DBF

from .config import Config

logger = logging.getLogger(__name__)


class DBFProcessor:
    """Processor for converting DBF files to CSV format."""

    # Whitelist of DBF files to process (files used in dimensional model and queries)
    # Only these files will be converted to CSV and loaded to BigQuery
    ALLOWED_FILES = {
        'claim',    # Used in transformations and queries (1, 3, 4, 5)
        'invoice',  # Used in bigquery queries (2, 3)
        # Add more files here as needed when you expand the data model:
        # 'custlist',
        # 'emplist',
        # 'pricelist',
    }

    def __init__(self, config: Optional[Config] = None):
        """Initialize DBF processor.

        Args:
            config: Application configuration. If None, uses default Config.
        """
        self.config = config or Config()

    def process_file(self, file_path: Path, output_path: Path) -> bool:
        """Process a single DBF file and save it as CSV.

        Args:
            file_path: Path to DBF file
            output_path: Path to output CSV file

        Returns:
            True if successful, False otherwise.
        """
        try:
            dbf = DBF(file_path, ignore_missing_memofile=True)
            df = pd.DataFrame(list(dbf))
            df.to_csv(output_path, index=False)
            logger.info(f"Processed {file_path} to {output_path}")
            return True
        except Exception as e:
            logger.error(f"Error processing {file_path}: {str(e)}")
            return False

    def process_directory(
        self, input_dir: Path, output_dir: Path
    ) -> dict[str, any]:
        """Process all DBF files in a directory.

        Args:
            input_dir: Directory containing DBF files
            output_dir: Directory to save CSV files

        Returns:
            Dictionary with processing results and statistics.
        """
        # Create output directory if it doesn't exist
        output_dir.mkdir(parents=True, exist_ok=True)

        results = {
            "files_processed": 0,
            "files_created": 0,
            "errors": [],
        }

        # Find all DBF files
        all_dbf_files = list(input_dir.glob("*.dbf")) + list(input_dir.glob("*.DBF"))

        if not all_dbf_files:
            logger.warning(f"No DBF files found in {input_dir}")
            return results

        # Filter to only process whitelisted files
        dbf_files = [
            f for f in all_dbf_files
            if f.stem.lower() in self.ALLOWED_FILES
        ]

        skipped = len(all_dbf_files) - len(dbf_files)
        if skipped > 0:
            logger.info(f"Skipping {skipped} files not in whitelist")
            logger.debug(f"Allowed files: {self.ALLOWED_FILES}")

        if not dbf_files:
            logger.warning(
                f"No whitelisted DBF files found in {input_dir}. "
                f"Looking for: {self.ALLOWED_FILES}"
            )
            return results

        logger.info(f"Found {len(dbf_files)} DBF files to process (filtered from {len(all_dbf_files)} total)")

        for dbf_file in dbf_files:
            output_file = output_dir / f"{dbf_file.stem}.csv"

            try:
                success = self.process_file(dbf_file, output_file)
                if success:
                    results["files_processed"] += 1
                    results["files_created"] += 1
                else:
                    results["errors"].append(f"Failed to process {dbf_file}")
            except Exception as e:
                error_msg = f"Error processing {dbf_file}: {str(e)}"
                logger.error(error_msg)
                results["errors"].append(error_msg)

        logger.info(
            f"Processed {results['files_processed']}/{len(dbf_files)} DBF files"
        )

        return results


# Legacy function for backward compatibility
def process_dbf_file(file_path: Path, output_path: Path) -> None:
    """Process a DBF file and save it as CSV.

    Legacy function for backward compatibility. Use DBFProcessor class instead.
    """
    processor = DBFProcessor()
    processor.process_file(file_path, output_path)


def process_all_dbf_files(config: Config) -> None:
    """Process all DBF files in the raw directory.

    Legacy function for backward compatibility. Use DBFProcessor class instead.
    """
    processor = DBFProcessor(config)
    processor.process_directory(config.RAW_DATA_DIR, config.PROCESSED_DATA_DIR)

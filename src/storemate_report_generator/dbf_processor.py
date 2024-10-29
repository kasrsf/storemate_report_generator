import logging
from pathlib import Path

import pandas as pd
from dbfread import DBF

from .config import Config

logger = logging.getLogger(__name__)


def process_dbf_file(file_path: Path, output_path: Path) -> None:
    """Process a DBF file and save it as CSV."""
    try:
        dbf = DBF(file_path, ignore_missing_memofile=True)

        # with open(output_path, 'w', newline='') as csv_file:
        #     writer = csv.writer(csv_file)

        #     # Write the header
        #     writer.writerow(dbf.field_names)

        #     # Write the rows
        #     for record in dbf:
        #         writer.writerow(record.values())
        df = pd.DataFrame(list(dbf))
        df.to_csv(output_path, index=False)
        logger.info(f"Processed {file_path} to {output_path}")
    except Exception as e:
        logger.error(f"Error processing {file_path}: {str(e)}")
        raise


def process_all_dbf_files(config: Config) -> None:
    """Process all DBF files in the raw directory."""
    config.PROCESSED_DATA_DIR.mkdir(parents=True, exist_ok=True)

    for dbf_file in config.RAW_DATA_DIR.glob("*.dbf"):
        output_file = config.PROCESSED_DATA_DIR / f"{dbf_file.stem}.csv"
        process_dbf_file(dbf_file, output_file)

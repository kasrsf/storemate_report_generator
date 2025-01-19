import logging

import click

from .config import Config
from .database import Database
from .dbf_processor import process_all_dbf_files
from .reporting import ReportGenerator
from .utils import backup_data_directory

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="$(asctime)s - %(name)s - %(levelname)s - %(message)s"
)


@click.group()
def cli():
    """Storemate Report Generator CLI."""
    pass


@cli.command()
def process_data():
    """Process DBF files to CSV format."""
    config = Config()
    process_all_dbf_files(config)


@cli.command()
@click.option("--month", type=int, help="Month (1-12)", default=None)
@click.option("--year", type=int, help="Year (YYYY)", default=None)
def generate_reports(month, year):
    """Generate reports from processed data."""
    config = Config()
    db = Database(config)
    try:
        db.load_csv_files()
        generator = ReportGenerator(config, db)
        generator.generate_all_reports(month=month, year=year)
    finally:
        db.close()


@cli.command()
def backup_data():
    """Create a backup of the data directory."""
    config = Config()
    backup_data_directory(config)


if __name__ == "__main__":
    cli()

import logging
import shutil
from datetime import datetime
from pathlib import Path

from .config import Config

logger = logging.getLogger(__name__)


def backup_data_directory(config: Config) -> Path:
    """Create a timestamped backup of the data directory."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = config.BACKUP_DIR / f"data_backup_{timestamp}.zip"

    try:
        config.BACKUP_DIR.mkdir(parents=True, exist_ok=True)
        shutil.make_archive(str(backup_path.with_suffix("")), "zip", config.RAW_DATA_DIR.parent)
        logger.info(f"Created backup at {backup_path}")
        return backup_path
    except Exception as e:
        logger.error(f"Error creating backup: {str(e)}")
        raise

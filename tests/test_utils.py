import zipfile

import pytest

from storemate_report_generator.utils import backup_data_directory


def test_backup_data_directory(test_config):
    # Create some  test files
    for subdir in ["raw", "processed", "reports"]:
        test_file = test_config.RAW_DATA_DIR.parent / subdir / "test.txt"
        test_file.write_text("test content")

    backup_path = backup_data_directory(test_config)

    # Verify backup was created
    assert backup_path.exists()
    assert zipfile.is_zipfile(backup_path)

    # Verify backup contents
    with zipfile.ZipFile(backup_path) as zf:
        files = [f for f in zf.namelist() if not f.endswith("/")]
        assert len(files) == 3  # One file from each subdirectory
        assert all(f.endswith("test.txt") for f in files)


def test_backup_data_directory_error(test_config):
    # Make backup directory read-only
    test_config.BACKUP_DIR.chmod(0o444)

    with pytest.raises(Exception):
        backup_data_directory(test_config)

    # Cleanup
    test_config.BACKUP_DIR.chmod(0o777)

"""Google Cloud Storage client for file management."""

import logging
from pathlib import Path
from typing import Optional

from google.cloud import storage

from .config import Config

logger = logging.getLogger(__name__)


class GCSClient:
    """Client for managing Google Cloud Storage operations."""

    def __init__(self, config: Optional[Config] = None):
        """Initialize GCS client.

        Args:
            config: Application configuration. If None, uses default Config.
        """
        self.config = config or Config()

        if not self.config.GCP_STORAGE_BUCKET:
            raise ValueError(
                "GCP_STORAGE_BUCKET not set. "
                "Please set the GCP_STORAGE_BUCKET environment variable."
            )

        # Initialize Storage client
        self.client = storage.Client(project=self.config.GCP_PROJECT_ID)
        self.bucket = self.client.bucket(self.config.GCP_STORAGE_BUCKET)

        logger.info(
            f"Initialized GCS client for bucket: {self.config.GCP_STORAGE_BUCKET}"
        )

    def upload_file(
        self, local_path: Path, destination_blob_name: Optional[str] = None
    ) -> storage.Blob:
        """Upload a file to GCS.

        Args:
            local_path: Path to local file
            destination_blob_name: Name for the blob in GCS.
                                   If None, uses the filename.

        Returns:
            The uploaded blob.
        """
        if destination_blob_name is None:
            destination_blob_name = local_path.name

        blob = self.bucket.blob(destination_blob_name)
        blob.upload_from_filename(str(local_path))

        logger.info(
            f"Uploaded {local_path} to gs://{self.config.GCP_STORAGE_BUCKET}/{destination_blob_name}"
        )

        return blob

    def upload_directory(
        self, local_dir: Path, gcs_prefix: str = ""
    ) -> list[storage.Blob]:
        """Upload all files from a directory to GCS.

        Args:
            local_dir: Local directory to upload
            gcs_prefix: Prefix for GCS paths (e.g., 'data/raw/')

        Returns:
            List of uploaded blobs.
        """
        blobs = []

        for file_path in local_dir.rglob("*"):
            if file_path.is_file():
                # Calculate relative path
                relative_path = file_path.relative_to(local_dir)
                destination_blob_name = f"{gcs_prefix}{relative_path}"

                try:
                    blob = self.upload_file(file_path, destination_blob_name)
                    blobs.append(blob)
                except Exception as e:
                    logger.error(f"Failed to upload {file_path}: {e}")
                    continue

        logger.info(f"Uploaded {len(blobs)} files from {local_dir}")
        return blobs

    def download_file(
        self, blob_name: str, local_path: Path
    ) -> None:
        """Download a file from GCS.

        Args:
            blob_name: Name of the blob in GCS
            local_path: Local path to save the file
        """
        blob = self.bucket.blob(blob_name)

        # Create parent directory if it doesn't exist
        local_path.parent.mkdir(parents=True, exist_ok=True)

        blob.download_to_filename(str(local_path))

        logger.info(
            f"Downloaded gs://{self.config.GCP_STORAGE_BUCKET}/{blob_name} to {local_path}"
        )

    def list_blobs(self, prefix: Optional[str] = None) -> list[storage.Blob]:
        """List all blobs in the bucket with an optional prefix.

        Args:
            prefix: Optional prefix to filter blobs

        Returns:
            List of blobs.
        """
        blobs = list(self.client.list_blobs(self.bucket, prefix=prefix))
        logger.info(f"Found {len(blobs)} blobs with prefix '{prefix}'")
        return blobs

    def delete_blob(self, blob_name: str) -> None:
        """Delete a blob from GCS.

        Args:
            blob_name: Name of the blob to delete
        """
        blob = self.bucket.blob(blob_name)
        blob.delete()
        logger.info(
            f"Deleted gs://{self.config.GCP_STORAGE_BUCKET}/{blob_name}"
        )

    def blob_exists(self, blob_name: str) -> bool:
        """Check if a blob exists.

        Args:
            blob_name: Name of the blob to check

        Returns:
            True if blob exists, False otherwise.
        """
        blob = self.bucket.blob(blob_name)
        return blob.exists()

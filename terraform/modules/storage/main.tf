# Cloud Storage Module - Data Lake and Backups

resource "google_storage_bucket" "storemate_bucket" {
  name     = var.bucket_name
  location = var.location
  project  = var.project_id

  # Storage class
  storage_class = var.storage_class

  # Versioning for data protection
  versioning {
    enabled = var.versioning_enabled
  }

  # Lifecycle rules
  lifecycle_rule {
    condition {
      age = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }

  # Move old backups to cheaper storage
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Labels
  labels = merge(
    var.labels,
    {
      environment = var.environment
      purpose     = "data-lake"
    }
  )

  # Force destroy (set to false in production)
  force_destroy = var.force_destroy
}

# Create folder structure using objects
resource "google_storage_bucket_object" "data_folder" {
  name    = "data/.gitkeep"
  content = "# Data files go here"
  bucket  = google_storage_bucket.storemate_bucket.name
}

resource "google_storage_bucket_object" "backups_folder" {
  name    = "backups/.gitkeep"
  content = "# Automated backups go here"
  bucket  = google_storage_bucket.storemate_bucket.name
}

resource "google_storage_bucket_object" "archive_folder" {
  name    = "archive/.gitkeep"
  content = "# Archived data goes here"
  bucket  = google_storage_bucket.storemate_bucket.name
}

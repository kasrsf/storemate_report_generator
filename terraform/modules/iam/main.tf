# IAM Module - Service Account and Permissions

resource "google_service_account" "etl_service_account" {
  account_id   = var.service_account_id
  display_name = "StoreMate ETL Service Account"
  description  = "Service account for automated ETL pipeline operations"
}

# BigQuery Data Editor - Create and modify tables
resource "google_project_iam_member" "bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.etl_service_account.email}"
}

# BigQuery Job User - Run queries and jobs
resource "google_project_iam_member" "bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.etl_service_account.email}"
}

# Storage Object Admin - Manage files in GCS
resource "google_storage_bucket_iam_member" "storage_object_admin" {
  bucket = var.storage_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.etl_service_account.email}"
}

# Cloud Functions Invoker - Allow scheduler to invoke function
resource "google_project_iam_member" "cloud_function_invoker" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.etl_service_account.email}"
}

# Service Account User - Allow Cloud Functions to use this SA
resource "google_project_iam_member" "service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.etl_service_account.email}"
}

# Cloud Build Service Account - Allow building Cloud Functions
resource "google_project_iam_member" "cloud_build_service_account" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.etl_service_account.email}"
}

# Artifact Registry Reader - Allow accessing build artifacts
resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.etl_service_account.email}"
}

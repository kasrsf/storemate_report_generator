# Cloud Function Module - Automated ETL

# Create a bucket for Cloud Function source code
resource "google_storage_bucket" "function_source" {
  name     = "${var.project_id}-function-source"
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true
  force_destroy = true
}

# Copy source code to cloud_function directory before packaging
resource "null_resource" "prepare_function_package" {
  triggers = {
    # Trigger when source files change
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Clean up old package if it exists
      rm -rf ${var.source_dir}/storemate_report_generator

      # Copy the source package into cloud_function directory
      cp -r ${var.source_dir}/../src/storemate_report_generator ${var.source_dir}/

      # Clean up __pycache__ and .pyc files
      find ${var.source_dir}/storemate_report_generator -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
      find ${var.source_dir}/storemate_report_generator -type f -name "*.pyc" -delete 2>/dev/null || true
    EOT
  }
}

# Package the Cloud Function source code
data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/function-source.zip"
  excludes    = ["__pycache__", "*.pyc", "deploy.sh", "README.md"]

  depends_on = [null_resource.prepare_function_package]
}

# Upload source code to GCS
resource "google_storage_bucket_object" "function_source" {
  name   = "function-source-${data.archive_file.function_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.function_source.output_path
}

# Deploy Cloud Function (Gen 2)
resource "google_cloudfunctions2_function" "etl_function" {
  name     = var.function_name
  location = var.region
  project  = var.project_id

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    max_instance_count    = var.max_instances
    min_instance_count    = var.min_instances
    available_memory      = var.memory
    timeout_seconds       = var.timeout
    service_account_email = var.service_account

    environment_variables = merge(
      {
        GCP_PROJECT_ID      = var.project_id
        GCP_DATASET_NAME    = var.dataset_name
        GCP_LOCATION        = "US"
        GCP_STORAGE_BUCKET  = var.storage_bucket_name
      },
      var.environment_vars
    )
  }

  labels = var.labels
}

# Allow unauthenticated access (for Cloud Scheduler)
resource "google_cloud_run_service_iam_member" "invoker" {
  project  = google_cloudfunctions2_function.etl_function.project
  location = google_cloudfunctions2_function.etl_function.location
  service  = google_cloudfunctions2_function.etl_function.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.service_account}"
}

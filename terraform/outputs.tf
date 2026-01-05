# Outputs for StoreMate Infrastructure

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "dataset_id" {
  description = "BigQuery dataset ID"
  value       = module.bigquery.dataset_id
}

output "dataset_location" {
  description = "BigQuery dataset location"
  value       = module.bigquery.dataset_location
}

output "storage_bucket_name" {
  description = "Cloud Storage bucket name"
  value       = module.storage.bucket_name
}

output "storage_bucket_url" {
  description = "Cloud Storage bucket URL"
  value       = module.storage.bucket_url
}

output "service_account_email" {
  description = "Service account email for ETL operations"
  value       = module.iam.service_account_email
}

# Environment variables for local CLI
output "environment_variables" {
  description = "Environment variables to set for local development"
  value       = <<-EOT
    # Add these to your .env file or shell profile:
    export GCP_PROJECT_ID="${var.project_id}"
    export GCP_DATASET_NAME="${var.dataset_name}"
    export GCP_LOCATION="${var.bigquery_location}"
    export GCP_STORAGE_BUCKET="${var.storage_bucket_name}"
    export GOOGLE_APPLICATION_CREDENTIALS="path/to/your/key.json"
  EOT
}

# Quick start commands
output "next_steps" {
  description = "Commands to run after infrastructure is deployed"
  value       = <<-EOT
    Infrastructure deployed successfully!

    Next steps:

    1. Download service account key:
       gcloud iam service-accounts keys create ~/.config/gcloud/storemate-key.json \
         --iam-account=${module.iam.service_account_email}

    2. Set environment variables (see 'environment_variables' output above)

    3. Test GCP connection:
       uv run storemate-cli test-gcp

    4. Run initial data sync:
       uv run storemate-cli sync-to-bigquery

    5. View your data in BigQuery:
       https://console.cloud.google.com/bigquery?project=${var.project_id}

    6. Set up Looker Studio dashboards using queries in bigquery_queries/

    Note: Data syncs are manual. Run 'uv run storemate-cli sync-to-bigquery' regularly to update BigQuery.
  EOT
}

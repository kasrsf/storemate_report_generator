# StoreMate Report Generator - Main Terraform Configuration
# This file orchestrates all infrastructure components

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Uncomment to use GCS backend for state management
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "storemate/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# IAM - Service Account for ETL
module "iam" {
  source = "./modules/iam"

  project_id          = var.project_id
  service_account_id  = var.service_account_id
  dataset_name        = var.dataset_name
  storage_bucket_name = var.storage_bucket_name

  depends_on = [google_project_service.required_apis]
}

# BigQuery - Data Warehouse
module "bigquery" {
  source = "./modules/bigquery"

  project_id   = var.project_id
  dataset_name = var.dataset_name
  location     = var.bigquery_location
  description  = var.dataset_description

  depends_on = [google_project_service.required_apis]
}

# Cloud Storage - Data Lake & Backups
module "storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  bucket_name = var.storage_bucket_name
  location    = var.storage_location
  environment = var.environment

  depends_on = [google_project_service.required_apis]
}

# Cloud Function - Automated ETL
module "cloud_function" {
  source = "./modules/cloud_function"

  project_id          = var.project_id
  function_name       = var.function_name
  region              = var.region
  runtime             = var.function_runtime
  entry_point         = var.function_entry_point
  source_dir          = var.function_source_dir
  service_account     = module.iam.service_account_email
  dataset_name        = var.dataset_name
  storage_bucket_name = var.storage_bucket_name
  environment_vars    = var.function_environment_vars

  depends_on = [
    google_project_service.required_apis,
    module.iam,
    module.bigquery,
    module.storage,
  ]
}

# Cloud Scheduler - Automated Triggers
module "scheduler" {
  source = "./modules/scheduler"

  project_id      = var.project_id
  region          = var.region
  job_name        = var.scheduler_job_name
  schedule        = var.scheduler_schedule
  time_zone       = var.scheduler_timezone
  function_uri    = module.cloud_function.function_url
  service_account = module.iam.service_account_email

  depends_on = [
    google_project_service.required_apis,
    module.cloud_function,
  ]
}

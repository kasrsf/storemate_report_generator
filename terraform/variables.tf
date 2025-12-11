# Variables for StoreMate Infrastructure

# Project Configuration
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Default GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# BigQuery Configuration
variable "dataset_name" {
  description = "BigQuery dataset name"
  type        = string
  default     = "storemate_data"
}

variable "bigquery_location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "US"
}

variable "dataset_description" {
  description = "BigQuery dataset description"
  type        = string
  default     = "StoreMate POS data warehouse with dimensional model"
}

# Cloud Storage Configuration
variable "storage_bucket_name" {
  description = "Cloud Storage bucket name (must be globally unique)"
  type        = string
}

variable "storage_location" {
  description = "Cloud Storage bucket location"
  type        = string
  default     = "US"
}

# IAM Configuration
variable "service_account_id" {
  description = "Service account ID for ETL operations"
  type        = string
  default     = "storemate-etl"
}

# Cloud Function Configuration
variable "function_name" {
  description = "Cloud Function name"
  type        = string
  default     = "storemate-etl"
}

variable "function_runtime" {
  description = "Cloud Function runtime"
  type        = string
  default     = "python311"
}

variable "function_entry_point" {
  description = "Cloud Function entry point"
  type        = string
  default     = "sync_data_http"
}

variable "function_source_dir" {
  description = "Path to Cloud Function source code"
  type        = string
  default     = "../cloud_function"
}

variable "function_environment_vars" {
  description = "Environment variables for Cloud Function"
  type        = map(string)
  default     = {}
}

# Cloud Scheduler Configuration
variable "scheduler_job_name" {
  description = "Cloud Scheduler job name"
  type        = string
  default     = "storemate-daily-sync"
}

variable "scheduler_schedule" {
  description = "Cloud Scheduler cron schedule"
  type        = string
  default     = "0 2 * * *" # Daily at 2 AM
}

variable "scheduler_timezone" {
  description = "Timezone for Cloud Scheduler"
  type        = string
  default     = "America/Los_Angeles"
}

# Budget & Alerts
variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 50
}

variable "budget_alert_thresholds" {
  description = "Budget alert threshold percentages"
  type        = list(number)
  default     = [0.5, 0.9, 1.0]
}

# Tags
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    application = "storemate"
    managed_by  = "terraform"
  }
}

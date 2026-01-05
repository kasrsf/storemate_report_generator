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

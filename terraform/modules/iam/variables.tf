variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "service_account_id" {
  description = "Service account ID"
  type        = string
}

variable "dataset_name" {
  description = "BigQuery dataset name for permissions"
  type        = string
}

variable "storage_bucket_name" {
  description = "Storage bucket name for permissions"
  type        = string
}

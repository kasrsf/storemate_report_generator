variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "function_name" {
  description = "Cloud Function name"
  type        = string
}

variable "region" {
  description = "Cloud Function region"
  type        = string
}

variable "runtime" {
  description = "Cloud Function runtime"
  type        = string
  default     = "python311"
}

variable "entry_point" {
  description = "Cloud Function entry point"
  type        = string
}

variable "source_dir" {
  description = "Path to source code directory"
  type        = string
}

variable "service_account" {
  description = "Service account email for the function"
  type        = string
}

variable "dataset_name" {
  description = "BigQuery dataset name"
  type        = string
}

variable "storage_bucket_name" {
  description = "Cloud Storage bucket name"
  type        = string
}

variable "memory" {
  description = "Memory allocation for the function"
  type        = string
  default     = "512Mi"
}

variable "timeout" {
  description = "Function timeout in seconds"
  type        = number
  default     = 540
}

variable "max_instances" {
  description = "Maximum number of function instances"
  type        = number
  default     = 1
}

variable "min_instances" {
  description = "Minimum number of function instances"
  type        = number
  default     = 0
}

variable "environment_vars" {
  description = "Additional environment variables"
  type        = map(string)
  default     = {}
}

variable "labels" {
  description = "Labels to apply to the function"
  type        = map(string)
  default     = {}
}

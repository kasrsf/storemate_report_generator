variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "bucket_name" {
  description = "Cloud Storage bucket name (must be globally unique)"
  type        = string
}

variable "location" {
  description = "Bucket location"
  type        = string
  default     = "US"
}

variable "storage_class" {
  description = "Storage class for the bucket"
  type        = string
  default     = "STANDARD"
}

variable "versioning_enabled" {
  description = "Enable versioning for data protection"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Days to retain backup files before deletion"
  type        = number
  default     = 90
}

variable "force_destroy" {
  description = "Allow destroying bucket with contents (use false in production)"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "labels" {
  description = "Labels to apply to the bucket"
  type        = map(string)
  default     = {}
}

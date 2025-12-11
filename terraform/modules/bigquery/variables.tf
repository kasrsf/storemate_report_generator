variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "dataset_name" {
  description = "BigQuery dataset name"
  type        = string
}

variable "location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "US"
}

variable "description" {
  description = "Dataset description"
  type        = string
  default     = "StoreMate POS data warehouse"
}

variable "default_table_expiration_ms" {
  description = "Default table expiration in milliseconds (null for no expiration)"
  type        = number
  default     = null
}

variable "delete_contents_on_destroy" {
  description = "Whether to delete dataset contents when destroying"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to the dataset"
  type        = map(string)
  default     = {}
}

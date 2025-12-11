variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Cloud Scheduler region"
  type        = string
}

variable "job_name" {
  description = "Scheduler job name"
  type        = string
}

variable "schedule" {
  description = "Cron schedule (e.g., '0 2 * * *' for daily at 2 AM)"
  type        = string
}

variable "time_zone" {
  description = "Timezone for the schedule"
  type        = string
  default     = "America/Los_Angeles"
}

variable "function_uri" {
  description = "Cloud Function URI to invoke"
  type        = string
}

variable "service_account" {
  description = "Service account email for authentication"
  type        = string
}

variable "retry_count" {
  description = "Number of retry attempts"
  type        = number
  default     = 3
}

variable "max_retry_duration" {
  description = "Maximum retry duration in seconds"
  type        = number
  default     = 600
}

variable "min_backoff_duration" {
  description = "Minimum backoff duration in seconds"
  type        = number
  default     = 5
}

variable "max_backoff_duration" {
  description = "Maximum backoff duration in seconds"
  type        = number
  default     = 3600
}

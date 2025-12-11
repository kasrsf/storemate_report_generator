# Cloud Scheduler Module - Automated Triggers

resource "google_cloud_scheduler_job" "etl_schedule" {
  name      = var.job_name
  region    = var.region
  project   = var.project_id
  schedule  = var.schedule
  time_zone = var.time_zone

  http_target {
    uri         = var.function_uri
    http_method = "POST"

    oidc_token {
      service_account_email = var.service_account
    }
  }

  retry_config {
    retry_count          = var.retry_count
    max_retry_duration   = "${var.max_retry_duration}s"
    min_backoff_duration = "${var.min_backoff_duration}s"
    max_backoff_duration = "${var.max_backoff_duration}s"
  }
}

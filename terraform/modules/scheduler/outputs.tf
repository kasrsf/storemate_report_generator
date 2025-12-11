output "job_name" {
  description = "Cloud Scheduler job name"
  value       = google_cloud_scheduler_job.etl_schedule.name
}

output "schedule" {
  description = "Cron schedule"
  value       = google_cloud_scheduler_job.etl_schedule.schedule
}

output "job_id" {
  description = "Cloud Scheduler job ID"
  value       = google_cloud_scheduler_job.etl_schedule.id
}

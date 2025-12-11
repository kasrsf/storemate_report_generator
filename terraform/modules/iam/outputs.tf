output "service_account_email" {
  description = "Service account email address"
  value       = google_service_account.etl_service_account.email
}

output "service_account_name" {
  description = "Service account name"
  value       = google_service_account.etl_service_account.name
}

output "service_account_id" {
  description = "Service account ID"
  value       = google_service_account.etl_service_account.account_id
}

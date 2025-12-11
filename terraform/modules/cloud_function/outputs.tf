output "function_name" {
  description = "Cloud Function name"
  value       = google_cloudfunctions2_function.etl_function.name
}

output "function_url" {
  description = "Cloud Function HTTP trigger URL"
  value       = google_cloudfunctions2_function.etl_function.service_config[0].uri
}

output "function_id" {
  description = "Cloud Function ID"
  value       = google_cloudfunctions2_function.etl_function.id
}

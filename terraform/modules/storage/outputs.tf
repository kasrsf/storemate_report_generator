output "bucket_name" {
  description = "Cloud Storage bucket name"
  value       = google_storage_bucket.storemate_bucket.name
}

output "bucket_url" {
  description = "Cloud Storage bucket URL"
  value       = google_storage_bucket.storemate_bucket.url
}

output "bucket_self_link" {
  description = "Cloud Storage bucket self link"
  value       = google_storage_bucket.storemate_bucket.self_link
}

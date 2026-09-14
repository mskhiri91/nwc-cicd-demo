output "landing_bucket" {
  value = google_storage_bucket.landing.name
}

output "temp_bucket" {
  value = google_storage_bucket.temp.name
}

output "datasets" {
  value = { for k, v in google_bigquery_dataset.layer : k => v.dataset_id }
}

output "datafusion_endpoint" {
  description = "Base URL of the CDAP REST API for this environment"
  value       = try(google_data_fusion_instance.df[0].service_endpoint, "not created")
}

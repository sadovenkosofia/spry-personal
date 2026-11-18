output "api_url" {
  value = google_cloud_run_v2_service.api.uri
}

output "image_repo" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.spry.repository_id}"
}

output "db_connection_name" {
  value = google_sql_database_instance.main.connection_name
}

output "hosting_url" {
  value = "https://${var.project_id}.web.app"
}

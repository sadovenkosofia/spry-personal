resource "google_artifact_registry_repository" "spry" {
  location      = var.region
  repository_id = "spry"
  format        = "DOCKER"
  description   = "Spry backend images"

  depends_on = [google_project_service.apis]
}

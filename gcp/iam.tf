# The identity the API runs as. Not the default compute service account (that one has Editor).
resource "google_service_account" "api" {
  account_id   = "spry-api"
  display_name = "Spry API (Cloud Run)"
  depends_on   = [google_project_service.apis]
}

resource "google_project_iam_member" "api_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api.email}"
}

resource "google_secret_manager_secret_iam_member" "api_database_url" {
  secret_id = google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

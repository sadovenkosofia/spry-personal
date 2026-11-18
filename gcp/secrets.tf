# The app reads one env var, DATABASE_URL (backend/app/config.py), so the whole URL is the secret.
# Host is empty and `host=` points at the Cloud SQL unix socket that Cloud Run mounts at /cloudsql.
locals {
  database_url = "postgresql+psycopg://${google_sql_user.spry.name}:${random_password.db.result}@/${google_sql_database.spry.name}?host=/cloudsql/${google_sql_database_instance.main.connection_name}"
}

resource "google_secret_manager_secret" "database_url" {
  secret_id = "spry-database-url"
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = local.database_url
}

# Plain password too: needed for pg_dump / psql through the Cloud SQL Auth Proxy.
resource "google_secret_manager_secret" "db_password" {
  secret_id = "spry-db-password"
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}

resource "google_sql_database_instance" "main" {
  name                = "spry-db"
  region              = var.region
  database_version    = var.db_version
  deletion_protection = false # lab project: `terraform destroy` must work

  settings {
    tier              = var.db_tier
    edition           = "ENTERPRISE" # db-f1-micro exists only in Enterprise edition
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = 10
    disk_autoresize   = false

    backup_configuration {
      enabled = false
    }

    # Public IP, but no authorized networks: Cloud Run connects through the
    # Cloud SQL socket (IAM-authorised), not over the open internet.
    ip_configuration {
      ipv4_enabled = true
    }
  }

  lifecycle {
    # `make gcp-db-stop` / `gcp-db-start` flip this with gcloud; do not fight it.
    ignore_changes = [settings[0].activation_policy]
  }

  depends_on = [google_project_service.apis]
}

resource "google_sql_database" "spry" {
  name     = "spry"
  instance = google_sql_database_instance.main.name
}

resource "random_password" "db" {
  length  = 32
  special = false # keeps the password safe inside a URL without encoding
}

resource "google_sql_user" "spry" {
  name     = "spry"
  instance = google_sql_database_instance.main.name
  password = random_password.db.result
}

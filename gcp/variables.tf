variable "project_id" {
  type        = string
  description = "GCP project ID, e.g. spry-sofia-2026"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "db_version" {
  type        = string
  default     = "POSTGRES_17"
  description = "Cloud SQL engine. Local docker-compose uses 18; use the newest POSTGRES_* that Cloud SQL offers."
}

variable "db_tier" {
  type    = string
  default = "db-f1-micro"
}

# Terraform only creates the service with this placeholder image.
# Real images are rolled out with `make gcp-deploy-api` (see lifecycle in cloudrun.tf).
variable "bootstrap_image" {
  type    = string
  default = "us-docker.pkg.dev/cloudrun/container/hello"
}

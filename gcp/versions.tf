terraform {
  required_version = ">= 1.10"

  # Separate workspace from the AWS one (demo-dev): one plan can never touch both clouds.
  # In HCP Terraform set this workspace's Execution Mode to "Local":
  # the run uses your gcloud application default credentials, state is still stored in HCP.
  cloud {
    organization = "ooad-sadovenkosofia"
    workspaces {
      name = "spry-gcp"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

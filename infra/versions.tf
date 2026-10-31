terraform {
  required_version = ">= 1.10"

  cloud {
    organization = "ooad-sadovenkosofia"
    workspaces {
      name = "demo-dev"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = { PROJECT_NAME = var.project_name }
  }
}

# Cognito lives in us-east-1
provider "aws" {
  alias  = "auth"
  region = var.auth_region

  default_tags {
    tags = { PROJECT_NAME = var.project_name }
  }
}

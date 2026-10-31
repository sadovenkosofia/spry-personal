variable "project_name" {
  type    = string
  default = "demo"
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "auth_region" {
  type    = string
  default = "us-east-1"
}

# --- auth
variable "domain_prefix" {
  type = string
}

variable "google_client_id" {
  type = string
}

variable "google_client_secret" {
  type      = string
  sensitive = true
}

variable "callback_urls" {
  type = list(string)
}

variable "logout_urls" {
  type = list(string)
}

# --- reports
variable "builder_image_uri" {
  type = string
}

variable "database_url" {
  type      = string
  sensitive = true
}

variable "report_email" {
  type = string
}

variable "schedule_expression" {
  type    = string
  default = "cron(0 7 ? * MON *)"
}

variable "fail_week" {
  type    = string
  default = "none"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "route_table_id" {
  type = string
}

# --- ai
variable "parser_image_uri" {
  type = string
}

variable "parser_model" {
  type    = string
  default = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "allowed_origins" {
  type = list(string)
}
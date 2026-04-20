# ============================================================
# Module: gcp-otel-project — Input Variables
# ============================================================

variable "project_id" {
  description = "The GCP project ID to create"
  type        = string
}

variable "project_name" {
  description = "The display name for the GCP project"
  type        = string
}

variable "builder_sa_name" {
  description = "The account ID of the CI/CD Builder service account"
  type        = string
  default     = "service-cicd"
}

variable "app_sa_name" {
  description = "The account ID of the Cloud Run app runtime service account"
  type        = string
  default     = "service-cloudrun"
}

variable "billing_account" {
  description = "The billing account ID (format: XXXXXX-XXXXXX-XXXXXX)"
  type        = string
  sensitive   = true
}

variable "org_id" {
  description = "GCP organization ID. Leave empty for personal accounts."
  type        = string
  default     = ""
}

variable "folder_id" {
  description = "GCP folder ID. Leave empty to create at root."
  type        = string
  default     = ""
}

variable "region" {
  description = "Default GCP region"
  type        = string
  default     = "asia-east1"
}

variable "repo_name" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "otel-demo"
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

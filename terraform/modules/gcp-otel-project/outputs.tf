# ============================================================
# Module: gcp-otel-project — Outputs
# ============================================================

output "project_id" {
  description = "The created GCP project ID"
  value       = google_project.this.project_id
}

output "project_number" {
  description = "The GCP project number"
  value       = data.google_project.this.number
}

output "artifact_registry_url" {
  description = "Artifact Registry Docker repository URL"
  value       = "${var.region}-docker.pkg.dev/${google_project.this.project_id}/${var.repo_name}"
}

output "cloud_build_sa" {
  description = "Cloud Build service account email"
  value       = google_service_account.cicd_builder.email
}

output "app_runtime_sa" {
  description = "Cloud Run runtime service account email"
  value       = google_service_account.app_runtime.email
}


# ============================================================
# Module: gcp_tenant_project — Outputs
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
  value       = "${local.region}-docker.pkg.dev/${google_project.this.project_id}/${try(var.tenant.repo_name, "app-images")}"
}

output "builder_sa_email" {
  description = "CI/CD Builder service account email"
  value       = google_service_account.cicd_builder.email
}

output "runtime_sa_email" {
  description = "Cloud Run runtime service account email"
  value       = google_service_account.app_runtime.email
}

output "summary" {
  description = "Human-readable project setup summary"
  value = {
    project_id   = google_project.this.project_id
    environment  = var.tenant.project.environment
    region       = local.region
    builder_sa   = google_service_account.cicd_builder.email
    runtime_sa   = google_service_account.app_runtime.email
    registry_url = "${local.region}-docker.pkg.dev/${google_project.this.project_id}/${try(var.tenant.repo_name, "app-images")}"
  }
}

# ============================================================
# Module: gcp_tenant_project — Artifact Registry
# ============================================================

resource "google_artifact_registry_repository" "docker" {
  project       = google_project.this.project_id
  location      = local.region
  repository_id = try(var.tenant.repo_name, "app-images")
  description   = "Container images for ${var.tenant.project.name}"
  format        = "DOCKER"

  cleanup_policy_dry_run = false
  labels                 = local.labels

  depends_on = [google_project_service.apis["artifactregistry.googleapis.com"]]
}

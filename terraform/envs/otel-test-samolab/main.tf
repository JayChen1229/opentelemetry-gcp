# ============================================================
# Environment: otel-test-samolab — Call the shared module
# ============================================================

variable "region" {
  type    = string
  default = "asia-east1"
}

module "project" {
  source = "../../modules/gcp-otel-project"

  project_id      = "otel-test-samolab"
  project_name    = "OTel Demo Project"
  billing_account = "010F46-806C7A-9B87C5"
  region          = var.region
  repo_name       = "otel-demo"

  # 👇 加上你決定的精準命名
  builder_sa_name = "service-cicd"
  app_sa_name     = "service-cloudrun"

  labels = {
    environment = "test"
  }
}

# ── Outputs ─────────────────────────────────────────────────

output "project_id" {
  value = module.project.project_id
}

output "project_number" {
  value = module.project.project_number
}

output "artifact_registry_url" {
  value = module.project.artifact_registry_url
}

output "cloud_build_sa" {
  value = module.project.cloud_build_sa
}

output "app_runtime_sa" {
  value = module.project.app_runtime_sa
}

output "next_steps" {
  value = <<-EOT
    ✅ GCP project "${module.project.project_id}" setup complete!

    Service Account for Cloud Run:
      ${module.project.app_runtime_sa}

    Next steps:
      gcloud auth configure-docker ${var.region}-docker.pkg.dev --quiet
      gcloud builds submit --config=cloudbuild-all.yaml \
        --project=${module.project.project_id} \
        --substitutions=SHORT_SHA=$(git rev-parse --short HEAD)
  EOT
}
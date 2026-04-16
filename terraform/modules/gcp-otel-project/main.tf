# ============================================================
# Module: gcp-otel-project
# ============================================================
# Creates a fully configured GCP project for OTel demo:
#   Project → APIs → Artifact Registry → IAM
# ============================================================

locals {
  labels = merge({
    managed-by = "terraform"
    purpose    = "opentelemetry"
  }, var.labels)
}

# ── Project ─────────────────────────────────────────────────

resource "google_project" "this" {
  name       = var.project_name
  project_id = var.project_id

  org_id    = var.folder_id == "" && var.org_id != "" ? var.org_id : null
  folder_id = var.folder_id != "" ? var.folder_id : null

  billing_account = var.billing_account
  deletion_policy = "DELETE"

  labels = local.labels
}

# ── APIs ────────────────────────────────────────────────────

locals {
  required_apis = [
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudtrace.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = google_project.this.project_id
  service            = each.value
  disable_on_destroy = false
}

# ── Artifact Registry ──────────────────────────────────────

resource "google_artifact_registry_repository" "docker" {
  project       = google_project.this.project_id
  location      = var.region
  repository_id = var.repo_name
  description   = "Container images for ${var.project_name}"
  format        = "DOCKER"

  cleanup_policy_dry_run = false
  labels                 = local.labels

  depends_on = [google_project_service.apis["artifactregistry.googleapis.com"]]
}

# ── Cloud Build IAM ────────────────────────────────────────

data "google_project" "this" {
  project_id = google_project.this.project_id
  depends_on = [google_project_service.apis["cloudresourcemanager.googleapis.com"]]
}

locals {
  cloud_build_sa = "${data.google_project.this.number}@cloudbuild.gserviceaccount.com"

  cloud_build_roles = [
    "roles/run.admin",
    "roles/iam.serviceAccountUser",
    "roles/artifactregistry.writer",
  ]
}

resource "google_project_iam_member" "cloud_build" {
  for_each = toset(local.cloud_build_roles)

  project = google_project.this.project_id
  role    = each.value
  member  = "serviceAccount:${local.cloud_build_sa}"

  depends_on = [
    google_project_service.apis["cloudbuild.googleapis.com"],
    google_project_service.apis["iam.googleapis.com"],
  ]
}

# ── Cloud Run App Runtime SA ───────────────────────────────

resource "google_service_account" "app_runtime" {
  project      = google_project.this.project_id
  account_id   = "otel-app-runtime"
  display_name = "OTel App Runtime Service Account"
  description  = "Service account for Cloud Run apps to send traces, metrics, and logs"

  depends_on = [google_project_service.apis["iam.googleapis.com"]]
}

locals {
  app_runtime_roles = [
    "roles/cloudtrace.agent",        # 寫入 Trace
    "roles/monitoring.metricWriter", # 寫入 Metrics
    "roles/logging.logWriter"        # 寫入 Logs
  ]
}

resource "google_project_iam_member" "app_runtime_permissions" {
  for_each = toset(local.app_runtime_roles)

  project = google_project.this.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.app_runtime.email}"
}


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

# ── Custom CI/CD Builder SA ────────────────────────────────

resource "google_project_iam_member" "cicd_builder_permissions" {
  for_each = toset(local.cicd_builder_roles)

  project = google_project.this.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cicd_builder.email}"
}

locals {
  # 注意：我們已經將 "roles/iam.serviceAccountUser" 從這個專案層級的清單中移除了
  cicd_builder_roles = [
    "roles/run.admin",               # To deploy Cloud Run services
    "roles/artifactregistry.writer", # To push/pull images to/from Artifact Registry
    "roles/logging.logWriter",       # To write build logs
    "roles/storage.admin",           # To extract source code from GCS tarball
  ]
}

# ── Cloud Run App Runtime SA ───────────────────────────────

# ── CI/CD Builder SA ──
resource "google_service_account" "cicd_builder" {
  project      = google_project.this.project_id
  account_id   = var.builder_sa_name
  display_name = "CI/CD Builder SA (${var.builder_sa_name})"
}

# ── Cloud Run App Runtime SA ──
resource "google_service_account" "app_runtime" {
  project      = google_project.this.project_id
  account_id   = var.app_sa_name
  display_name = "Cloud Run Runtime SA (${var.app_sa_name})"
}

locals {
  app_runtime_roles = [
    "roles/cloudtrace.agent",        # 寫入 Trace
    "roles/monitoring.metricWriter", # 寫入 Metrics
    "roles/logging.logWriter",       # 寫入 Logs
    "roles/artifactregistry.reader"  # 拉 image 跑容器
  ]
}

resource "google_project_iam_member" "app_runtime_permissions" {
  for_each = toset(local.app_runtime_roles)

  project = google_project.this.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.app_runtime.email}"
}

# ── 【重點資安升級】: 精細授權 Builder 只能使用 Runtime SA ──

resource "google_service_account_iam_member" "builder_can_act_as_runtime" {
  # 這裡針對的是 app_runtime 這個「資源」本身，而不是整個 Project
  service_account_id = google_service_account.app_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cicd_builder.email}"
}

# ── Compute Engine Default SA ──────────────────────────────

locals {
  compute_default_sa = "${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "compute_default_ar_reader" {
  project = google_project.this.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${local.compute_default_sa}"
  depends_on = [
    google_project_service.apis["iam.googleapis.com"],
  ]
}
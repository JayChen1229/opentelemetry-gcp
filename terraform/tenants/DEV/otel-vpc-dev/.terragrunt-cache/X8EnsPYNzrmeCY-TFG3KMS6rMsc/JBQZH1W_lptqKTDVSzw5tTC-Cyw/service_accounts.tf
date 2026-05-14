# ============================================================
# Module: gcp_tenant_project — Service Accounts
# ============================================================
# 建立兩個核心 SA：
#   1. CI/CD Builder — 負責打包、推圖、部署
#   2. App Runtime  — Cloud Run 執行時身分
# ============================================================

# ── CI/CD Builder SA ───────────────────────────────────────

resource "google_service_account" "cicd_builder" {
  project      = google_project.this.project_id
  account_id   = var.tenant.builder_sa.name
  display_name = "CI/CD Builder SA (${var.tenant.builder_sa.name})"
  description  = "User-managed SA for Cloud Build: build, push, deploy"

  depends_on = [google_project_service.apis["iam.googleapis.com"]]
}

# ── Cloud Run App Runtime SA ──────────────────────────────

resource "google_service_account" "app_runtime" {
  project      = google_project.this.project_id
  account_id   = var.tenant.runtime_sa.name
  display_name = "Cloud Run Runtime SA (${var.tenant.runtime_sa.name})"
  description  = "App runtime identity: traces, metrics, logs, secrets"

  depends_on = [google_project_service.apis["iam.googleapis.com"]]
}

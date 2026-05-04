# ============================================================
# Module: gcp_tenant_project — GCP Project 建立
# ============================================================
# 一個 Module 實例 = 一個完整的 GCP 租戶專案
# 所有設定由外部 YAML 透過 var.tenant 傳入
# ============================================================

locals {
  project_id = var.tenant.project.id
  region     = try(var.tenant.project.region, "asia-east1")
  labels = merge({
    managed-by  = "terraform"
    environment = lower(var.tenant.project.environment)
  }, try(var.tenant.labels, {}))
}

# ── GCP Project ────────────────────────────────────────────

resource "google_project" "this" {
  name       = var.tenant.project.name
  project_id = local.project_id

  org_id    = var.folder_id == "" && var.org_id != "" ? var.org_id : null
  folder_id = var.folder_id != "" ? var.folder_id : null

  billing_account = var.billing_account
  deletion_policy = lower(var.tenant.project.environment) == "prod" ? "PREVENT" : "DELETE"

  labels = local.labels
}

# ── 等待 API 啟用生效 ──────────────────────────────────────
# GCP API 啟用有 eventual consistency，新專案需要短暫等待
resource "time_sleep" "wait_for_apis" {
  create_duration = "30s"

  depends_on = [google_project_service.apis]
}

# ── Data Source：取得 Project Number ──

data "google_project" "this" {
  project_id = google_project.this.project_id
  depends_on = [time_sleep.wait_for_apis]
}

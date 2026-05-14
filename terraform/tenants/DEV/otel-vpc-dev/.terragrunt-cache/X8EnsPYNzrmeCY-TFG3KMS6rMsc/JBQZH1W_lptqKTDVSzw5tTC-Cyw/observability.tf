# ============================================================
# Module: gcp_tenant_project — 集中式觀測 (Observability Scope)
# ============================================================
# 用途：將此專案的 Metrics/Trace 資料連結到中心監控專案
# 前提：需要有一個 central_ops_project_id
# ============================================================

# ── Metrics Scope 關聯 ─────────────────────────────────────
# 讓中心監控專案能「跨專案」查詢此專案的 Metrics

resource "google_monitoring_monitored_project" "this" {
  count = try(var.tenant.observability.link_metrics_scope, false) ? 1 : 0

  metrics_scope = "locations/global/metricsScopes/${var.tenant.observability.central_ops_project_id}"
  name          = local.project_id

  depends_on = [
    google_project_service.apis["monitoring.googleapis.com"],
  ]
}

# ── 未來擴充區 ─────────────────────────────────────────────
# Trace Scope: 目前 GCP 尚無獨立的 Terraform resource，
# 但可透過 google_monitoring_monitored_project 間接實現。
# 當 Google 推出 google_cloudtrace_scope resource 時再補上。

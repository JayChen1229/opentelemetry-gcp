# ============================================================
# Module: gcp_tenant_project — API 啟用
# ============================================================
# API 清單從 YAML 的 enabled_apis 傳入
# 若 YAML 未指定，使用 variables.tf 中的預設清單
# ============================================================

resource "google_project_service" "apis" {
  for_each = toset(var.tenant.enabled_apis)

  project            = google_project.this.project_id
  service            = each.value
  disable_on_destroy = false # 安全防護：destroy 時不關閉 API
}

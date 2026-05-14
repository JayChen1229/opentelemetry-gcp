# ============================================================
# Module: gcp_tenant_project — 預算警報 (FinOps Budget Alert)
# ============================================================
# 只有在 YAML 中定義了 budget_control 時才會建立
# ============================================================

# ── 自動啟用 Billing Budget API（僅在需要時）──
resource "google_project_service" "billing_budget_api" {
  count = try(var.tenant.budget_control, null) != null ? 1 : 0

  project            = google_project.this.project_id
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

resource "google_billing_budget" "this" {
  count = try(var.tenant.budget_control, null) != null ? 1 : 0

  billing_account = var.billing_account
  display_name    = "Budget: ${var.tenant.project.name} (${var.tenant.project.environment})"

  budget_filter {
    projects = ["projects/${google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.tenant.budget_control.monthly_limit_usd)
    }
  }

  dynamic "threshold_rules" {
    for_each = try(var.tenant.budget_control.alert_thresholds, [0.5, 0.8, 1.0])
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  all_updates_rule {
    monitoring_notification_channels = []
    disable_default_iam_recipients   = false

    # 預算警報會發到 billing admins
    # 如果未來需要發到 Slack/PagerDuty，可透過 notification_channels 設定
  }

  depends_on = [
    google_project_service.billing_budget_api,
  ]
}

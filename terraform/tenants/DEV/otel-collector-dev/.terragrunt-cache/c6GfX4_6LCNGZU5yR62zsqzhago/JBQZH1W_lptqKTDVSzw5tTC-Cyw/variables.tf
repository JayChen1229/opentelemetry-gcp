# ============================================================
# Module: gcp_tenant_project — Input Variables
# ============================================================
# tenant 變數由外部 YAML 解析後傳入
# 使用 type = any 保持彈性，搭配 try() 處理 optional 欄位
# ============================================================

variable "tenant" {
  description = <<-EOT
    完整的租戶設定，由 YAML 檔案解析而來。預期結構：

    project:
      id:          string  (必填) GCP Project ID
      name:        string  (必填) 顯示名稱
      environment: string  (必填) dev/sit/prod
      region:      string  (選填) 預設 asia-east1

    enabled_apis:  list(string) (必填) 需要啟用的 GCP API

    builder_sa:
      name:  string        (必填) CI/CD SA account_id
      roles: list(string)  (必填) Project 層級 IAM roles

    runtime_sa:
      name:  string        (必填) Runtime SA account_id
      roles: list(string)  (必填) Project 層級 IAM roles

    repo_name:     string  (選填) Artifact Registry repo name

    labels:        map     (選填) 額外 labels

    budget_control:         (選填) 預算控制
      monthly_limit_usd: number
      alert_thresholds:  list(number)
      notify_email:      string

    observability:          (選填) 集中式觀測
      central_ops_project_id: string
      link_metrics_scope:     bool

    user_access:            (選填) 人員權限
      <group_name>:
        members: list(string)
        roles:   list(string)
  EOT
  type        = any

  validation {
    condition     = try(var.tenant.project.id, "") != ""
    error_message = "tenant.project.id is required and cannot be empty."
  }

  validation {
    condition     = try(var.tenant.project.name, "") != ""
    error_message = "tenant.project.name is required and cannot be empty."
  }

  validation {
    condition     = try(var.tenant.project.environment, "") != ""
    error_message = "tenant.project.environment is required (dev/sit/prod)."
  }

  validation {
    condition     = try(length(var.tenant.enabled_apis), 0) > 0
    error_message = "tenant.enabled_apis must contain at least one API."
  }

  validation {
    condition     = try(var.tenant.builder_sa.name, "") != ""
    error_message = "tenant.builder_sa.name is required."
  }

  validation {
    condition     = try(var.tenant.runtime_sa.name, "") != ""
    error_message = "tenant.runtime_sa.name is required."
  }
}

variable "billing_account" {
  description = "GCP Billing Account ID (format: XXXXXX-XXXXXX-XXXXXX)"
  type        = string
  sensitive   = true
}

variable "org_id" {
  description = "GCP Organization ID. Leave empty for personal accounts."
  type        = string
  default     = ""
}

variable "folder_id" {
  description = "GCP Folder ID. Leave empty to create at org/account root."
  type        = string
  default     = ""
}

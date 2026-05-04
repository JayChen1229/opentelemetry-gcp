# ============================================================
# Bootstrap — Variables
# ============================================================

variable "state_project_id" {
  description = "用來存放 Terraform State bucket 的 GCP 專案 ID"
  type        = string
}

variable "region" {
  description = "GCS bucket 的位置"
  type        = string
  default     = "asia-east1"
}

# ============================================================
# Module: gcp_tenant_project — Provider & Version Constraints
# ============================================================
# Terragrunt 模式下，此 Module 即為 root module，
# 因此需要在這裡定義 provider
# ============================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# provider 不設定 project — 每個資源各自使用 tenant YAML 中的 project_id

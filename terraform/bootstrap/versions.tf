# ============================================================
# Bootstrap — Provider & Version Constraints
# ============================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Bootstrap 的 State 存本地，commit 到 Git
  # 它只管一個 bucket，風險極低
}

provider "google" {
  project = var.state_project_id
  region  = var.region
}

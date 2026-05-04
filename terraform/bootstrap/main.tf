# ============================================================
# Bootstrap — 建立 Terraform Remote State 儲存 (只需執行一次)
# ============================================================
# 用途：建立一個 GCS bucket 來集中存放所有環境的 tfstate
# 此模組的 State 存在本地並 commit 到 Git
# ============================================================

resource "google_storage_bucket" "tfstate" {
  name     = "${var.state_project_id}-tfstate"
  project  = var.state_project_id
  location = var.region

  # ── 安全設定 ──
  uniform_bucket_level_access = true # 統一存取控制，禁止 ACL
  public_access_prevention    = "enforced"

  # ── State 版控：可回溯任意一次 apply ──
  versioning {
    enabled = true
  }

  # ── 自動清理過舊的版本，只保留最近 10 個 ──
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 10
    }
  }

  labels = {
    managed-by = "terraform"
    purpose    = "tfstate"
  }
}

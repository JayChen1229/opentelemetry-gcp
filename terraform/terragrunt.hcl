# ============================================================
# Terragrunt — 根層級共用設定
# ============================================================
# 所有租戶繼承此設定，自動產生獨立的 Remote State 路徑
# ============================================================

# ── Remote State：每個租戶自動隔離 ──
remote_state {
  backend = "gcs"
  config = {
    bucket   = get_env("TF_STATE_BUCKET", "sincere-essence-384903-tfstate")
    prefix   = "${path_relative_to_include()}/terraform.tfstate"
    project  = get_env("TF_STATE_PROJECT", "sincere-essence-384903")
    location = "asia-east1"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# ── 自動產生 provider.tf ──
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
provider "google" {
  # project 不在這裡設定 — 由 module 內各資源自行指定
}
EOF
}

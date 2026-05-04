# ============================================================
# Tenant: otel-test-samolab (DEV)
# ============================================================

# ── 繼承根層級設定 (backend + provider) ──
include "root" {
  path = find_in_parent_folders()
}

# ── 讀取環境共用變數 ──
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  tenant   = yamldecode(file("tenant.yaml"))
}

# ── 指向共用 Module ──
terraform {
  source = "../../../modules/gcp_tenant_project"
}

# ── 傳入變數 ──
inputs = {
  tenant          = local.tenant
  billing_account = local.env_vars.locals.billing_account
}

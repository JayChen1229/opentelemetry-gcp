# ============================================================
# Module: gcp_tenant_project — IAM 權限綁定
# ============================================================
# 三層 IAM 設計：
#   1. SA → Project 層級權限 (builder_sa.roles / runtime_sa.roles)
#   2. SA → SA 精細授權 (builder actAs runtime)
#   3. User → Project 層級權限 (user_access.developers / admins)
# ============================================================

# ── 1. CI/CD Builder — Project 層級權限 ────────────────────

resource "google_project_iam_member" "cicd_builder_permissions" {
  for_each = toset(var.tenant.builder_sa.roles)

  project = google_project.this.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cicd_builder.email}"
}

# ── 2. App Runtime — Project 層級權限 ─────────────────────

resource "google_project_iam_member" "app_runtime_permissions" {
  for_each = toset(var.tenant.runtime_sa.roles)

  project = google_project.this.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.app_runtime.email}"
}

# ── 3.【資安升級】Builder 只能 actAs Runtime SA ────────────
# 精細到 SA 層級，而非整個 Project 的 serviceAccountUser

resource "google_service_account_iam_member" "builder_can_act_as_runtime" {
  service_account_id = google_service_account.app_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cicd_builder.email}"
}

# ── 4. Compute Engine Default SA — AR 讀取 ────────────────

locals {
  compute_default_sa = "${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "compute_default_ar_reader" {
  project = google_project.this.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${local.compute_default_sa}"

  depends_on = [google_project_service.apis["iam.googleapis.com"]]
}

# ── 5. User / 人員權限 (選配) ─────────────────────────────
# YAML 中 user_access 是 optional，只有定義了才會建立

locals {
  # 展平 user_access map 成 (group_name, role) 的組合
  # 例如: { "developers/roles/viewer" = { members = [...], role = "roles/viewer" } }
  user_access_bindings = merge([
    for group_name, group in try(var.tenant.user_access, {}) : {
      for role in group.roles :
      "${group_name}/${role}" => {
        members = group.members
        role    = role
      }
    }
  ]...)
}

resource "google_project_iam_member" "user_access" {
  for_each = {
    for item in flatten([
      for key, binding in local.user_access_bindings : [
        for member in binding.members : {
          key    = "${key}/${member}"
          role   = binding.role
          member = "user:${member}"
        }
      ]
    ]) : item.key => item
  }

  project = google_project.this.project_id
  role    = each.value.role
  member  = each.value.member
}

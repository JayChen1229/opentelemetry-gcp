# ============================================================
# Module: gcp_tenant_project — 跨專案 IAM 綁定
# ============================================================
# 兩種模式：
#   1. cross_project_iam    — 直接指定外部 SA email + roles
#   2. cross_project_agents — 指定 project_id，自動解析
#      GCP 內建 Service Agent (Cloud Build / Cloud Run) 的 email
# ============================================================

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 模式 1：直接指定 SA (user-managed SA 或已知 email)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  cross_project_bindings = flatten([
    for entry in try(var.tenant.cross_project_iam, []) : [
      for role in entry.roles : {
        key    = "${entry.member}/${role}"
        member = entry.member
        role   = role
      }
    ]
  ])
}

resource "google_project_iam_member" "cross_project" {
  for_each = { for b in local.cross_project_bindings : b.key => b }

  project = google_project.this.project_id
  role    = each.value.role
  member  = each.value.member
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 模式 2：GCP 內建 Service Agent (自動查詢 project number)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# YAML 範例：
#   cross_project_agents:
#     - project_id: "otel-apps-dev"
#       cloudbuild_roles:   # → service-{NUMBER}@gcp-sa-cloudbuild.iam.gserviceaccount.com
#         - "roles/compute.networkAdmin"
#       cloudrun_roles:     # → service-{NUMBER}@serverless-robot-prod.iam.gserviceaccount.com
#         - "roles/compute.networkUser"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  agent_projects = try(var.tenant.cross_project_agents, [])

  # 將 project_id list 轉成 map 供 data source 使用
  agent_project_ids = { for p in local.agent_projects : p.project_id => p }
}

# ── 動態查詢外部專案的 Project Number ──
data "google_project" "agents" {
  for_each   = local.agent_project_ids
  project_id = each.key
}

locals {
  # 展平 Cloud Build Agent bindings
  cloudbuild_agent_bindings = flatten([
    for entry in local.agent_projects : [
      for role in try(entry.cloudbuild_roles, []) : {
        key    = "cloudbuild/${entry.project_id}/${role}"
        member = "serviceAccount:service-${data.google_project.agents[entry.project_id].number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
        role   = role
      }
    ]
  ])

  # 展平 Cloud Run Agent (Serverless Robot) bindings
  cloudrun_agent_bindings = flatten([
    for entry in local.agent_projects : [
      for role in try(entry.cloudrun_roles, []) : {
        key    = "cloudrun/${entry.project_id}/${role}"
        member = "serviceAccount:service-${data.google_project.agents[entry.project_id].number}@serverless-robot-prod.iam.gserviceaccount.com"
        role   = role
      }
    ]
  ])

  all_agent_bindings = concat(
    local.cloudbuild_agent_bindings,
    local.cloudrun_agent_bindings
  )
}

resource "google_project_iam_member" "cross_project_agents" {
  for_each = { for b in local.all_agent_bindings : b.key => b }

  project = google_project.this.project_id
  role    = each.value.role
  member  = each.value.member
}

# Walkthrough: Terraform 企業級架構重構

## 變更總覽

將原本的單一 Module + 單一 Env 結構，重構為 **YAML 驅動的多租戶 GCP Project Factory**。

### Before → After

```
# ❌ 舊架構                          # ✅ 新架構
terraform/                            terraform/
├── modules/gcp-otel-project/         ├── bootstrap/          ← 🔒 State bucket (只跑一次)
│   ├── main.tf (151 行全擠一起)      │   ├── main.tf
│   ├── variables.tf                  │   ├── variables.tf
│   └── outputs.tf                    │   ├── outputs.tf
├── envs/otel-test-samolab/           │   └── versions.tf
│   ├── main.tf                       │
│   └── versions.tf                   └── platform/           ← 🏗️ 管所有租戶
└── test.yaml (設計草稿)                  ├── locals.tf       ← ⭐ YAML 動態讀取
                                          ├── projects.tf     ← for_each module
                                          ├── variables.tf
                                          ├── outputs.tf
                                          ├── versions.tf
                                          ├── modules/
                                          │   └── gcp_tenant_project/
                                          │       ├── main.tf           ← Project
                                          │       ├── apis.tf           ← APIs
                                          │       ├── registry.tf       ← AR
                                          │       ├── service_accounts.tf ← SAs
                                          │       ├── iam.tf            ← IAM
                                          │       ├── observability.tf  ← Scope
                                          │       ├── budget.tf         ← FinOps
                                          │       ├── variables.tf
                                          │       └── outputs.tf
                                          ├── envs/
                                          │   └── DEV.tfvars
                                          └── tenants/
                                              ├── DEV/
                                              │   └── otel-test-samolab.yaml
                                              ├── SIT/
                                              └── PROD/
```

---

## 核心設計模式

### 1. YAML 驅動 (`locals.tf`)

```hcl
locals {
  tenant_files = fileset("${path.module}/tenants/${var.env}", "*.yaml")
  tenants = {
    for f in local.tenant_files :
    trimsuffix(f, ".yaml") => yamldecode(file(".../${f}"))
  }
}
```

**新增租戶只需要**：在 `tenants/DEV/` 下新增一個 `.yaml` 檔案，不需要改任何 `.tf` 檔。

### 2. 單一 Module 實現完整專案 (`gcp_tenant_project/`)

原本 151 行的 `main.tf` 拆分為 **9 個檔案**，按功能領域分離：

| 檔案 | 職責 | 對應 GCP 資源 |
|------|------|-------------|
| `main.tf` | Project 建立 | `google_project` |
| `apis.tf` | API 啟用 | `google_project_service` |
| `registry.tf` | Docker Registry | `google_artifact_registry_repository` |
| `service_accounts.tf` | SA 建立 | `google_service_account` × 2 |
| `iam.tf` | 權限綁定 | `google_project_iam_member` + `google_service_account_iam_member` |
| `observability.tf` | 觀測 Scope | `google_monitoring_monitored_project` |
| `budget.tf` | 預算警報 | `google_billing_budget` |
| `variables.tf` | 輸入驗證 | 6 項 validation rules |
| `outputs.tf` | 輸出 | project_id, SA emails, AR URL |

### 3. 環境隔離

```bash
# DEV 環境
terraform init -backend-config="prefix=platform/DEV"
terraform plan -var-file=envs/DEV.tfvars

# PROD 環境 (同一組 .tf，不同 State + 不同 YAML)
terraform init -backend-config="prefix=platform/PROD"
terraform plan -var-file=envs/PROD.tfvars
```

---

## 新增檔案清單

| 路徑 | 用途 |
|------|------|
| [main.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/bootstrap/main.tf) | Bootstrap: GCS State bucket |
| [variables.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/bootstrap/variables.tf) | Bootstrap: 變數 |
| [outputs.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/bootstrap/outputs.tf) | Bootstrap: 輸出 |
| [versions.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/bootstrap/versions.tf) | Bootstrap: Provider |
| [locals.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/locals.tf) | ⭐ YAML 動態讀取核心 |
| [projects.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/projects.tf) | for_each 模組呼叫 |
| [variables.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/variables.tf) | 環境層級變數 |
| [outputs.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/outputs.tf) | 彙總輸出 |
| [versions.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/versions.tf) | Provider 設定 |
| [main.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/modules/gcp_tenant_project/main.tf) | Module: Project |
| [apis.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/modules/gcp_tenant_project/apis.tf) | Module: APIs |
| [registry.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/modules/gcp_tenant_project/registry.tf) | Module: AR |
| [service_accounts.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/modules/gcp_tenant_project/service_accounts.tf) | Module: SAs |
| [iam.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/modules/gcp_tenant_project/iam.tf) | Module: IAM |
| [observability.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/modules/gcp_tenant_project/observability.tf) | Module: Scope |
| [budget.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/modules/gcp_tenant_project/budget.tf) | Module: Budget |
| [variables.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/modules/gcp_tenant_project/variables.tf) | Module: 輸入驗證 |
| [outputs.tf](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/modules/gcp_tenant_project/outputs.tf) | Module: 輸出 |
| [otel-test-samolab.yaml](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/tenants/DEV/otel-test-samolab.yaml) | 首個租戶設定 |
| [DEV.tfvars](file:///Users/jay/Documents/opentelemetry-gcp/terraform/platform/envs/DEV.tfvars) | DEV 環境變數 |

## 刪除檔案清單

| 路徑 | 原因 |
|------|------|
| `modules/gcp-otel-project/*` | 遷移到 `platform/modules/gcp_tenant_project/` |
| `envs/otel-test-samolab/*` | 被 YAML + tfvars 取代 |
| `test.yaml` | 設計草稿，已精煉為正式 tenant YAML |

---

## 驗證狀態

| 項目 | 狀態 |
|------|------|
| 目錄結構 | ✅ 22 個檔案，結構完整 |
| HCL 語法 (手動審查) | ✅ 無明顯語法錯誤 |
| `terraform fmt` | ⏳ 需在有 Terraform CLI 的環境執行 |
| `terraform init` | ⏳ 需在有 Terraform CLI 的環境執行 |
| `terraform validate` | ⏳ 需在有 Terraform CLI 的環境執行 |

---

## ⚠️ 下一步：你需要做的事

### 1. 在部署機上驗證

```bash
cd terraform/platform
terraform init
terraform validate
terraform fmt -check -recursive
```

### 2. State 遷移 (重要！)

你現有的 `otel-test-samolab` 專案已經有 local state。在新架構下跑 `terraform plan` 會想要**重新建立**這些資源（因為 State 裡沒有記錄）。

**兩條路**：

**選項 A：Import 現有資源 (推薦)**
```bash
cd terraform/platform
terraform init

# 匯入現有專案
terraform import -var-file=envs/DEV.tfvars \
  'module.tenant["otel-test-samolab"].google_project.this' \
  "otel-test-samolab"

# 匯入 API (每個都要)
terraform import -var-file=envs/DEV.tfvars \
  'module.tenant["otel-test-samolab"].google_project_service.apis["run.googleapis.com"]' \
  "otel-test-samolab/run.googleapis.com"

# 匯入 SA
terraform import -var-file=envs/DEV.tfvars \
  'module.tenant["otel-test-samolab"].google_service_account.cicd_builder' \
  "projects/otel-test-samolab/serviceAccounts/service-cicd@otel-test-samolab.iam.gserviceaccount.com"

# ... 以此類推
```

**選項 B：Destroy + Recreate (快但有停機)**
```bash
# 在舊目錄 destroy
cd terraform/envs/otel-test-samolab  # (已刪除，需從 Git 恢復)
terraform destroy

# 在新目錄 apply
cd terraform/platform
terraform apply -var-file=envs/DEV.tfvars
```

> 如果你需要，我可以幫你產生完整的 import 腳本。

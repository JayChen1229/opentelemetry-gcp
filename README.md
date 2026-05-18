# OpenTelemetry on GCP — 完整教學文件

> 使用 **Terraform + Terragrunt** 管理 GCP 專案，搭配 **集中式 OTel Collector** 實現
> Java / .NET / Python 三種語言的 **零侵入式 (zero-code)** 可觀測性。

---

## 1. 架構總覽

### 雙專案架構

```
┌─ otel-apps-dev (應用服務專案) ────────────┐     ┌─ otel-collector-dev (Collector 專案) ──┐
│                                            │     │                                        │
│  ┌─────────────┐                           │     │  ┌──────────────────────────────────┐  │
│  │ Java App    │──┐                        │     │  │ OTel Collector (Cloud Run)       │  │
│  └─────────────┘  │                        │     │  │                                  │  │
│  ┌─────────────┐  ├── OTLP (HTTP) ────────────────► │  receivers:  OTLP :4318          │  │
│  │ .NET App    │──┤                        │     │  │  exporters:                      │  │
│  └─────────────┘  │                        │     │  │    → Cloud Trace                 │  │
│  ┌─────────────┐  │                        │     │  │    → Cloud Monitoring            │  │
│  │ Python App  │──┘                        │     │  │    → Cloud Logging               │  │
│  └─────────────┘                           │     │  └──────────────────────────────────┘  │
│                                            │     │                                        │
│  SA: service-cloudrun                      │     │  SA: service-collector                 │
│                                            │     │     → cloudtrace.agent                 │
│                                            │     │     → monitoring.metricWriter           │
│                                            │     │     → logging.logWriter                 │
└────────────────────────────────────────────┘     └────────────────────────────────────────┘
```

> **💡 為什麼 OTLP 使用 HTTP (Port 4318) 而非 gRPC？**
> 在 Cloud Run 等使用 L7 Load Balancer 的環境中，HTTPS 的 TLS 終止由基礎設施處理。多數程式語言的 OTel SDK 看到 `https://` 端點時會預設使用 HTTP/Protobuf 傳輸。為避免 gRPC 與 HTTP/2 多路復用的相容性問題（如 HTTP 415 錯誤），我們選擇最穩定且相容性最佳的 HTTP (4318) 協定。

### 為什麼要分兩個專案？

| 考量 | 說明 |
|:-----|:-----|
| **職責分離** | Collector 是共用基礎設施，不應與業務服務混在一起 |
| **獨立擴展** | Collector 可獨立 scale，不影響應用部署 |
| **多專案共用** | 未來其他專案的服務也能傳送資料到同一個 Collector |

---

## 2. 專案結構

```
opentelemetry-gcp/
├── terraform/                              # 🏗️ 基礎架構 (IaC)
│   ├── terragrunt.hcl                     #   根層級設定 (GCS backend)
│   ├── 使用教學.md                         #   Terraform 操作教學
│   ├── bootstrap/                         #   一次性：建立 tfstate GCS Bucket
│   ├── modules/
│   │   └── gcp_tenant_project/            #   共用模組：1 module = 1 GCP 專案
│   └── tenants/
│       ├── DEV/
│       │   ├── env.hcl                    #   DEV 環境共用變數
│       │   ├── otel-collector-dev/        #   Collector 專案
│       │   ├── otel-apps-dev/             #   應用服務專案
│       │   └── otel-vpc-dev/              #   VPC 網路專案
│       ├── SIT/
│       └── PROD/
│
├── otel-collector/                         # 🔭 OTel Collector
│   ├── Dockerfile                         #   容器映像 (contrib)
│   ├── collector-config.yaml              #   Collector 設定
│   └── cloudbuild.yaml                    #   CI/CD pipeline
│
├── java-app/                               # ☕ Java Spring Boot (Zero-Code)
│   ├── Dockerfile                         #   安裝 OTel Java Agent + GCP Extension
│   ├── pom.xml                            #   Maven 專案設定 (無 OTel 依賴)
│   ├── cloudbuild.yaml                    #   CI/CD pipeline
│   ├── deploy/                            #   部署設定
│   │   ├── env-dev.yaml                   #     DEV 環境 OTel 設定
│   │   └── env-prod.yaml                  #     PROD 環境 OTel 設定
│   └── src/                               #   純業務程式碼 (無 OTel)
│
├── dotnet-app/                             # 🔷 .NET Core (NuGet 程式化注入)
│   ├── Dockerfile                         #   Multi-stage build
│   ├── DemoApp.csproj                     #   專案設定 (含 OTel NuGet packages)
│   ├── cloudbuild.yaml                    #   CI/CD pipeline
│   ├── deploy/                            #   部署設定
│   │   ├── env-dev.yaml                   #     DEV 環境 OTel 設定
│   │   └── env-prod.yaml                  #     PROD 環境 OTel 設定
│   └── src/
│       └── Program.cs                     #   OTel SDK 程式化初始化 + 業務程式碼
│
├── python-app/                             # 🐍 Python Flask (Zero-Code)
│   ├── Dockerfile                         #   安裝 OTel distro
│   ├── requirements.txt                   #   業務依賴
│   ├── requirements-otel.txt              #   OTel 依賴 (distro + GCP detector)
│   ├── cloudbuild.yaml                    #   CI/CD pipeline
│   ├── deploy/                            #   部署設定
│   │   ├── env-dev.yaml                   #     DEV 環境 OTel 設定
│   │   └── env-prod.yaml                  #     PROD 環境 OTel 設定
│   └── src/
│       └── app.py                         #   純業務程式碼 (無 OTel)
│
└── cloudbuild-all.yaml                     # 統一 CI/CD（一次部署三個服務）
```

---

## 3. 環境準備

### 3.1 安裝工具

```bash
# macOS
brew install terraform     # >= 1.5
brew install terragrunt    # >= 0.50

# 驗證
terraform --version
terragrunt --version
gcloud --version
```

### 3.2 GCP 認證

```bash
gcloud auth login
gcloud auth application-default login
```

---

## 4. 基礎架構部署 (Terraform)

### 4.1 Bootstrap — 建立 State Bucket（一次性）

```bash
cd terraform/bootstrap
terraform init
terraform apply -var="state_project_id=<你的管理專案ID>"
```

> ⚠️ `terraform/bootstrap/terraform.tfstate` 必須 commit 到 Git！

### 4.2 建立 Collector 專案

```bash
# 1. 準備 tenant.yaml（已有範本）
cd terraform/tenants/DEV/otel-collector-dev

# 2. 初始化 & 建立
terragrunt init
terragrunt plan     # 預覽 22 個資源
terragrunt apply    # 建立專案（約 2 分鐘）
```

**建立的資源：**

| 資源 | 說明 |
|:-----|:-----|
| GCP Project | `otel-collector-dev` |
| 8 APIs | run, cloudbuild, artifactregistry, cloudtrace, monitoring, logging, iam, cloudresourcemanager |
| Service Account | `service-cicd` — CI/CD 部署用 |
| Service Account | `service-collector` — Collector Runtime 用 |
| Artifact Registry | `otel-collector` — Docker images |
| IAM Bindings | SA 權限綁定 |

### 4.3 建立應用服務專案

```bash
cd terraform/tenants/DEV/otel-apps-dev
terragrunt init
terragrunt plan     # 預覽 25 個資源
terragrunt apply    # 建立專案（約 2 分鐘）
```

---

## 5. 部署 OTel Collector

### 5.1 Collector 設定檔

`otel-collector/collector-config.yaml`：

```yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318    # 應用傳送資料到這裡 (HTTP/Protobuf)

processors:
  batch:                           # 批次處理減少 API 呼叫
    send_batch_size: 256
    timeout: 5s
  resourcedetection:               # 自動偵測 GCP 資源標籤
    detectors: [env, gcp]
  memory_limiter:                  # 記憶體保護
    limit_percentage: 65

exporters:
  googlecloud:
    log:
      default_log_name: "opentelemetry-collector"
    metric:
      prefix: "custom.googleapis.com/otel"

service:
  extensions: [health_check]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, batch]
      exporters: [googlecloud]
```

### 5.2 Build & Deploy

```bash
# 方式 A：Cloud Build（推薦）
gcloud builds submit --config=otel-collector/cloudbuild.yaml \
  --project=otel-collector-dev

# 方式 B：手動部署
cd otel-collector
gcloud builds submit \
  --tag=asia-east1-docker.pkg.dev/otel-collector-dev/otel-collector/otel-collector:latest \
  --project=otel-collector-dev

gcloud run deploy otel-collector \
  --image=asia-east1-docker.pkg.dev/otel-collector-dev/otel-collector/otel-collector:latest \
  --region=asia-east1 \
  --project=otel-collector-dev \
  --port=4318 \
  --min-instances=1 \
  --allow-unauthenticated \
  --service-account=service-collector@otel-collector-dev.iam.gserviceaccount.com
```

### 5.3 取得 Collector URL

```bash
COLLECTOR_URL=$(gcloud run services describe otel-collector \
  --region=asia-east1 \
  --project=otel-collector-dev \
  --format="value(status.url)")

echo "Collector URL: ${COLLECTOR_URL}"
```

---

## 6. 部署應用服務

### 6.1 OTel 環境變數設定

每個服務都有 `deploy/env-dev.yaml` 和 `deploy/env-prod.yaml`，統一使用 OTLP (HTTP/Protobuf) 指向 Collector：

**Java (`java-app/deploy/env-dev.yaml`)**
```yaml
JAVA_TOOL_OPTIONS: "-javaagent:/opt/otel/opentelemetry-javaagent.jar"
OTEL_JAVAAGENT_EXTENSIONS: "/opt/otel/gcp-extension.jar"
OTEL_SERVICE_NAME: "java-demo-app"
OTEL_TRACES_EXPORTER: "otlp"
OTEL_METRICS_EXPORTER: "otlp"
OTEL_LOGS_EXPORTER: "otlp"
OTEL_EXPORTER_OTLP_PROTOCOL: "http/protobuf"
OTEL_EXPORTER_OTLP_ENDPOINT: "https://otel-collector-xxxxx.asia-east1.run.app"
OTEL_TRACES_SAMPLER: "parentbased_traceidratio"
OTEL_TRACES_SAMPLER_ARG: "1.0"
OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=DEV,service.namespace=otel-demo"
```

**.NET (`dotnet-app/deploy/env-dev.yaml`)** — 使用 NuGet 程式化注入
```yaml
OTEL_SERVICE_NAME: "dotnet-demo-app"
OTEL_EXPORTER_OTLP_PROTOCOL: "http/protobuf"
OTEL_EXPORTER_OTLP_ENDPOINT: "https://otel-collector-xxxxx.asia-east1.run.app"
OTEL_TRACES_SAMPLER: "parentbased_traceidratio"
OTEL_TRACES_SAMPLER_ARG: "1.0"
OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=DEV,service.namespace=otel-demo"
```

> 💡 .NET 已從 CLR Profiler 零侵入式改為 **NuGet 程式化注入**，在 `Program.cs` 中使用
> `AddGcpDetector()` 自動偵測 Cloud Run instance ID (`faas.instance`)。

**Python (`python-app/deploy/env-dev.yaml`)**
```yaml
OTEL_SERVICE_NAME: "python-demo-app"
OTEL_TRACES_EXPORTER: "otlp"
OTEL_METRICS_EXPORTER: "otlp"
OTEL_LOGS_EXPORTER: "otlp"
OTEL_EXPORTER_OTLP_ENDPOINT: "https://otel-collector-xxxxx.asia-east1.run.app"
OTEL_EXPORTER_OTLP_PROTOCOL: "http/protobuf"  # ⚠️ Python 預設為 gRPC，必須強制指定 HTTP
OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED: "true"
OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=DEV,service.namespace=otel-demo"
```

### 6.2 Deploy

```bash
# 全部一起部署
gcloud builds submit --config=cloudbuild-all.yaml \
  --project=otel-apps-dev \
  --substitutions=SHORT_SHA=$(git rev-parse --short HEAD)
```

### 6.3 開放測試存取

```bash
for svc in java-demo-app dotnet-demo-app python-demo-app; do
  gcloud run services add-iam-policy-binding $svc \
    --region=asia-east1 \
    --project=otel-apps-dev \
    --member="allUsers" \
    --role="roles/run.invoker" \
    --quiet
done
```

---

## 7. 驗證

### 7.1 測試應用

```bash
# 取得服務 URL
JAVA_URL=$(gcloud run services describe java-demo-app --region=asia-east1 --project=otel-apps-dev --format="value(status.url)")
DOTNET_URL=$(gcloud run services describe dotnet-demo-app --region=asia-east1 --project=otel-apps-dev --format="value(status.url)")
PYTHON_URL=$(gcloud run services describe python-demo-app --region=asia-east1 --project=otel-apps-dev --format="value(status.url)")

# 發送請求
curl $JAVA_URL/hello/world
curl $DOTNET_URL/hello/world
curl $PYTHON_URL/hello/world
```

### 7.2 查看 Traces

打開 GCP Console 的 Cloud Trace：

👉 https://console.cloud.google.com/traces?project=otel-collector-dev

你應該會看到來自三個服務的 traces，每個都標記了 `service.name` 和 `service.namespace`。

---

## 8. Instrumentation 策略

### 各語言注入方式

| 語言 | 注入方式 | Dockerfile 安裝 | 注入機制 | 設定檔 |
|:-----|:---------|:----------------|:---------|:-------|
| **Java** | Zero-Code | OTel Java Agent JAR + GCP Extension | `JAVA_TOOL_OPTIONS=-javaagent:...` | `deploy/env-{env}.yaml` |
| **.NET** | NuGet 程式化 | NuGet packages (含 GCP Resource Detector) | `Program.cs` 中 `AddGcpDetector()` | `deploy/env-{env}.yaml` |
| **Python** | Zero-Code | OTel distro + GCP Resource Detector | `opentelemetry-instrument` wrapper | `deploy/env-{env}.yaml` |

### 設計原則

```bash
# ❌ 不要這樣（hardcode 在 Dockerfile）
ENV OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"

# ✅ 應該這樣（透過 deploy/env-{env}.yaml 在部署時注入）
#    deploy/env-dev.yaml:
#      OTEL_EXPORTER_OTLP_ENDPOINT: "https://otel-collector-xxx.run.app"
```

---

## 9. FAQ

**Q: 應用程式碼真的完全不需要改嗎？**
A: Java 和 Python 是 Zero-Code，業務程式碼 100% 乾淨。.NET 改用 NuGet 程式化注入，需要在 `Program.cs` 中初始化 OTel SDK，但所有設定（endpoint、sampler 等）仍由 `deploy/env-{env}.yaml` 外部化控制。

**Q: 為什麼不用 gRPC 而改用 HTTP？**
A: 因為 Cloud Run 提供 L7 Load Balancer，各語言 SDK 透過 HTTPS 預設發送 HTTP/Protobuf 最穩定，不會遇到 gRPC 的憑證及 HTTP/2 降級導致的 HTTP 415 不相容問題。

**Q: 未來想加新的 backend（例如 Jaeger）怎麼做？**
A: 修改 `otel-collector/collector-config.yaml` 的 exporters，加入 Jaeger exporter 即可。應用端零改動。

**Q: 新增一個服務要改什麼？**
A: 只需要：(1) 建立 Dockerfile + cloudbuild.yaml + `deploy/env-{env}.yaml`，(2) 部署到對應專案。Collector 不需要任何修改。

**Q: Collector 掛了怎麼辦？**
A: 設定了 `min-instances=1` 保持暖啟動。應用端的 OTel agent 有內建重試機制，Collector 恢復後資料會自動補傳。

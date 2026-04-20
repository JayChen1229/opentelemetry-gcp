# OpenTelemetry Zero-Code Instrumentation on GCP Cloud Run

> 在 Cloud Run 上實現 **無嵌入程式碼 (zero-code)** 的 OpenTelemetry 自動追蹤，
> 支援 **Java / .NET Core / Python** 三種語言，並透過 **CI/CD 自動化** 整個流程。

## 📐 架構

### 現在 (3~5 服務) — 直接打 GCP

```
  App Container (OTel agent 注入)
    │
    └──► GCP Cloud Trace / Cloud Monitoring
         (直接輸出，無 Collector)
```

- Dockerfile 只安裝 agent，**不寫死任何 OTel 環境變數**
- 所有 OTel 設定 (`OTEL_SERVICE_NAME`, `OTEL_TRACES_EXPORTER`, ...) 由 **CI/CD 注入**
- Java / Python 使用 GCP-native exporter（ADC 自動認證）
- .NET 使用 OTLP exporter（搭配未來 Collector 或 GCP OTLP endpoint）

### 未來 (10+ 服務) — 加入集中 Collector

```
  App Container (OTel agent 注入)
    │
    └──► 集中式 OTel Collector ──► Cloud Trace / Monitoring
                                └──► Jaeger / Grafana / ...
```

> **遷移方式**：只改 CI/CD 變數 `OTEL_EXPORTER_OTLP_ENDPOINT`，不需要重建 image。

## 🎯 Zero-Code 原理

應用程式碼 **完全不需要** import 或使用任何 OpenTelemetry 套件。
所有追蹤功能都在 **Dockerfile** 安裝 agent，**CI/CD** 注入配置。

| 語言 | Dockerfile 安裝 | CI/CD 注入 | 如何運作 |
|------|----------------|-----------|---------|
| **Java** | Java Agent JAR + GCP exporter 擴展 | `OTEL_TRACES_EXPORTER=google_cloud_trace` | `JAVA_TOOL_OPTIONS` 注入 agent |
| **.NET** | CLR Profiler 安裝 | `OTEL_TRACES_EXPORTER=otlp` | `CORECLR_ENABLE_PROFILING=1` 啟動 |
| **Python** | OTel distro + GCP exporter pip 安裝 | `OTEL_TRACES_EXPORTER=gcp_trace` | `opentelemetry-instrument` 包裝啟動 |

### 關鍵設計：環境變數由 CI/CD 管理

```bash
# ❌ 不要這樣（hardcode 在 Dockerfile）
ENV OTEL_SERVICE_NAME="my-app"
ENV OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"

# ✅ 應該這樣（CI/CD deploy 時注入）
gcloud run deploy my-app \
  --set-env-vars="OTEL_SERVICE_NAME=my-app,OTEL_TRACES_EXPORTER=google_cloud_trace"
```

## 📁 專案結構

```
opentelemetry-gcp/
├── shared/                        # 共用配置
│   ├── otel-collector-config.yaml #   OTel Collector 設定 (未來使用)
│   └── cloud-run-service.yaml.tpl #   Cloud Run YAML 模板
├── java-app/                      # Java Spring Boot 範例
│   ├── src/                       #   純業務程式碼 (無 OTel)
│   ├── pom.xml                    #   僅業務依賴
│   ├── Dockerfile                 #   安裝 agent (不寫死 env vars)
│   └── cloudbuild.yaml            #   CI/CD → 注入 OTel env vars
├── dotnet-app/                    # .NET Core 範例
│   ├── Program.cs                 #   純業務程式碼 (無 OTel)
│   ├── DemoApp.csproj             #   僅業務依賴
│   ├── Dockerfile                 #   安裝 CLR Profiler (不寫死 env vars)
│   └── cloudbuild.yaml            #   CI/CD → 注入 OTel env vars
├── python-app/                    # Python Flask 範例
│   ├── app.py                     #   純業務程式碼 (無 OTel)
│   ├── requirements.txt           #   僅業務依賴
│   ├── requirements-otel.txt      #   OTel + GCP exporter (僅 CI/CD 使用)
│   ├── Dockerfile                 #   安裝 OTel (不寫死 env vars)
│   └── cloudbuild.yaml            #   CI/CD → 注入 OTel env vars
├── deploy/
│   ├── setup-gcp.sh               # 一鍵設定 GCP 環境
│   └── deploy-all.sh              # 一鍵部署（OTel env vars 在這裡）
├── cloudbuild-all.yaml            # 統一 Cloud Build pipeline
└── README.md
```

## 🚀 快速開始

### 前置需求

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud`)
- [Docker](https://docs.docker.com/get-docker/)
- GCP 專案並擁有 Owner / Editor 權限

### Step 1: 設定 GCP 環境

```bash
chmod +x deploy/setup-gcp.sh
./deploy/setup-gcp.sh <YOUR_PROJECT_ID> asia-east1
```

### Step 2: 部署到 Cloud Run

**方式 A：本機部署**

```bash
chmod +x deploy/deploy-all.sh
./deploy/deploy-all.sh <YOUR_PROJECT_ID> asia-east1
```

**方式 B：Cloud Build 自動部署**

```bash
gcloud builds submit --config=cloudbuild-all.yaml \
  --project=<YOUR_PROJECT_ID> \
  --substitutions=SHORT_SHA=$(git rev-parse --short HEAD)
```

**方式 C：單一服務部署**

```bash
gcloud builds submit --config=java-app/cloudbuild.yaml \
  --project=otel-test-samolab \
  --substitutions=SHORT_SHA=$(git rev-parse --short HEAD)


# dotnet 需要部署兩個 container, 故需要額外權限
gcloud projects add-iam-policy-binding otel-test-samolab \
  --member="serviceAccount:842429880657-compute@developer.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"
gcloud builds submit --config=dotnet-app/cloudbuild.yaml \
  --project=otel-test-samolab \
  --substitutions=SHORT_SHA=$(git rev-parse --short HEAD)
```

### Step 3: 測試

```bash
# 取得服務 URL
JAVA_URL=$(gcloud run services describe java-demo-app --region=asia-east1 --project=otel-test-samolab --format="value(status.url)")
DOTNET_URL=$(gcloud run services describe dotnet-demo-app --region=asia-east1 --project=otel-test-samolab --format="value(status.url)")
PYTHON_URL=$(gcloud run services describe python-demo-app --region=asia-east1 --format="value(status.url)")

# 允許未驗證的存取（測試用）
gcloud run services add-iam-policy-binding java-demo-app \
  --region=asia-east1 \
  --project=otel-test-samolab \
  --member="allUsers" \
  --role="roles/run.invoker"


gcloud run services add-iam-policy-binding dotnet-demo-app \
  --region=asia-east1 \
  --project=otel-test-samolab \
  --member="allUsers" \
  --role="roles/run.invoker"



gcloud run services add-iam-policy-binding python-demo-app \
  --region=asia-east1 \
  --project=otel-test-samolab \
  --member="allUsers" \
  --role="roles/run.invoker"

# 發送請求
curl ${JAVA_URL}/hello/world
curl ${DOTNET_URL}/hello/world
curl ${PYTHON_URL}/hello/world
```

### Step 4: 查看追蹤結果

1. **Cloud Trace**: https://console.cloud.google.com/traces?project=YOUR_PROJECT_ID
2. **Cloud Monitoring**: https://console.cloud.google.com/monitoring?project=YOUR_PROJECT_ID

## 🔄 遷移到集中式 Collector

當服務數量增加到 10+ 或需要多後端 (Jaeger, Grafana) 時：

```bash
# 只需改 CI/CD 變數，不需要重建 image
gcloud run deploy java-demo-app \
  --update-env-vars="OTEL_TRACES_EXPORTER=otlp,OTEL_EXPORTER_OTLP_ENDPOINT=https://your-collector.run.app"
```

應用層零改動 ✅

## 🔧 自訂配置

### 修改 Service Name

在 `cloudbuild.yaml` 的 `_OTEL_SERVICE_NAME` substitution 中修改。

### 修改 Sampling Rate

在 `cloudbuild.yaml` 的 substitutions 中修改：

```yaml
substitutions:
  _OTEL_TRACES_SAMPLER_ARG: "0.1"  # 10% sampling
```

### 關閉追蹤

```bash
gcloud run deploy my-app --update-env-vars="OTEL_SDK_DISABLED=true"
```

## ⚠️ .NET 注意事項

.NET auto-instrumentation 目前不支援 GCP-native exporter。有兩個選項：

1. **使用 OTLP exporter + 未來 Collector**：目前 OTel agent 已安裝但 endpoint 需要指向 Collector
2. **使用 Cloud Run sidecar**：取消 `cloud-run-service.yaml.tpl` 中的 sidecar 註解

建議：當你需要 .NET 的完整 tracing 時，優先引入集中式 Collector。

## ❓ FAQ

**Q: 應用程式碼真的完全不需要改嗎？**
A: 是的！Dockerfile 安裝 agent，CI/CD 注入配置。業務程式碼保持 100% 乾淨。

**Q: 未來切換到 Collector 時需要重建 image 嗎？**
A: 不需要！只改 CI/CD 變數: `OTEL_TRACES_EXPORTER=otlp` + `OTEL_EXPORTER_OTLP_ENDPOINT=http://your-collector:4317`

**Q: 哪些框架會被自動追蹤？**
A:
- Java: Spring Web MVC, Spring WebFlux, JDBC, gRPC, Kafka, Redis, etc.
- .NET: ASP.NET Core, HttpClient, EF Core, gRPC, etc.
- Python: Flask, Django, Requests, urllib3, psycopg2, etc.

**Q: 自動注入會影響效能嗎？**
A: 一般 overhead 在 1-3% 以內。Java Agent 啟動時間增加約 1-2 秒。

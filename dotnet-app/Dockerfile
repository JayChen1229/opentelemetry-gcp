# ============================================================
# Multi-stage Dockerfile for ASP.NET Core with
# OpenTelemetry .NET Auto-Instrumentation (zero-code)
# ============================================================
# 企業級最佳實踐：
# - 乾淨的 Runtime：將 curl, unzip 留在 Build stage
# - OTel 設定與 .NET Profiler 環境變數完全外部化 (env.yaml)
# - 非特權用戶運行 (APP_UID 1654)
# ============================================================

# ── Stage 1: Build & Prepare OTel ──
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

# 1. 準備專案與依賴緩存
WORKDIR /src
COPY DemoApp.csproj .
RUN dotnet restore

# 2. 下載 OTel .NET Auto-Instrumentation（不使用 install script，直接解壓）
#    無外網時：將 zip 預先上傳到 GCS，改用 COPY 或 gcloud storage cp 替代 curl
ARG OTEL_DOTNET_VERSION=1.9.0
RUN apt-get update && apt-get install -y unzip && \
    curl -fSL -o /tmp/otel-dotnet.zip \
    "https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/download/v${OTEL_DOTNET_VERSION}/opentelemetry-dotnet-instrumentation-linux-glibc-x64.zip" && \
    mkdir -p /opt/otel && \
    unzip -q /tmp/otel-dotnet.zip -d /opt/otel && \
    rm /tmp/otel-dotnet.zip

# 3. 編譯程式 (經常變動層放最後)
COPY . .
RUN dotnet publish -c Release -o /app/out

# ── Stage 2: Runtime ──
FROM mcr.microsoft.com/dotnet/aspnet:8.0

# 以 root 複製檔案並設定權限
USER root
WORKDIR /app
COPY --from=build /app/out .
COPY --from=build /opt/otel /opt/otel

# 微軟 .NET 8 內建名為 `app` 的非特權使用者 (UID 1654)
RUN chown -R 1654:1654 /app /opt/otel

# 切換為安全非特權使用者
USER 1654

# ┌─────────────────────────────────────────────────────────────┐
# │  ZERO-CODE INSTRUMENTATION                                  │
# │  OTel Agent is pre-installed in /opt/otel/.                 │
# │  All OTel config & .NET Profiler flags are externalized     │
# │  and injected via env-{env}.yaml at deploy time.            │
# │  This image is perfectly clean and OTel-agnostic.           │
# └─────────────────────────────────────────────────────────────┘

EXPOSE 8080

ENTRYPOINT ["dotnet", "DemoApp.dll"]

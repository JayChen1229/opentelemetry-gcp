# ============================================================
# OpenTelemetry Collector — Dockerfile
# ============================================================
# 集中式 Collector，部署在 Cloud Run
# 接收所有應用的 OTLP 遙測資料，匯出到 GCP
# ============================================================

# Base Image 來源：
#   我們現在統一透過 Cloud Build (--build-arg) 傳入內部 GAR Remote Repository 的位址。
#   這能同時解決有外網時的 Docker Hub Rate Limit 問題，以及無外網時無法拉取 Image 的問題。
#   如果在本機 (Local) 直接跑 docker build，則預設使用公開的 Docker Hub image。
ARG BASE_IMAGE=otel/opentelemetry-collector-contrib:0.140.0
FROM ${BASE_IMAGE}

COPY collector-config.yaml /etc/otelcol-contrib/config.yaml

# OTLP gRPC + HTTP + Health Check
EXPOSE 4317 4318 13133

CMD ["--config=/etc/otelcol-contrib/config.yaml"]

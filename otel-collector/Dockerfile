# ============================================================
# OpenTelemetry Collector — Dockerfile
# ============================================================
# 集中式 Collector，部署在 Cloud Run
# 接收所有應用的 OTLP 遙測資料，匯出到 GCP
# ============================================================

FROM otel/opentelemetry-collector-contrib:0.102.0

COPY collector-config.yaml /etc/otelcol-contrib/config.yaml

# OTLP gRPC + HTTP + Health Check
EXPOSE 4317 4318 13133

CMD ["--config=/etc/otelcol-contrib/config.yaml"]

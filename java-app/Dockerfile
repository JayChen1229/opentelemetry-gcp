# ============================================================
# Multi-stage Dockerfile for Java Spring Boot with
# OpenTelemetry Java Agent (zero-code instrumentation)
# ============================================================
# 企業級最佳實踐：
# - 三層快取策略（探針 → 依賴 → 原始碼）
# - 非特權用戶運行（UID 1001）
# - OTel 設定完全外部化（env-{env}.yaml）
# ============================================================

# ── Stage 1: Download OTel Agent + GCP Exporter (快取層 A：幾乎不變) ──
FROM curlimages/curl:latest AS otel-agent

ARG OTEL_AGENT_VERSION=2.26.1
ARG GCP_EXPORTER_VERSION=0.36.0-alpha

RUN curl -fL -o /tmp/opentelemetry-javaagent.jar \
    "https://repo1.maven.org/maven2/io/opentelemetry/javaagent/opentelemetry-javaagent/${OTEL_AGENT_VERSION}/opentelemetry-javaagent-${OTEL_AGENT_VERSION}.jar" && \
    curl -fL -o /tmp/gcp-extension.jar \
    "https://repo1.maven.org/maven2/com/google/cloud/opentelemetry/exporter-auto/${GCP_EXPORTER_VERSION}/exporter-auto-${GCP_EXPORTER_VERSION}-shaded.jar"

# ── Stage 2: Build the application ──
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /app

# 先只複製 pom.xml，下載專案依賴 (快取層 B：只要 pom.xml 沒改就不會重載)
COPY pom.xml ./
RUN mvn dependency:go-offline -B

# 最後才複製原始碼並打包 (頻繁變動層 C：每天 commit 只從這步開始)
COPY src ./src
RUN mvn package -DskipTests -B

# ── Stage 3: Runtime ──
FROM eclipse-temurin:21-jre

# 以 root 建立目錄並賦予適當權限，隨後降權
USER root
WORKDIR /app
RUN groupadd -g 1001 appgroup && \
    useradd -u 1001 -g appgroup -s /bin/sh appuser && \
    mkdir -p /opt/otel && \
    chown -R 1001:1001 /app /opt/otel

# 切換為非特權使用者，確保資安合規
USER 1001

# 1. 複製 OTel 探針
COPY --from=otel-agent /tmp/opentelemetry-javaagent.jar /opt/otel/
COPY --from=otel-agent /tmp/gcp-extension.jar /opt/otel/

# 2. 複製編譯好的業務程式
COPY --from=build /app/target/*.jar /app/app.jar

# ┌─────────────────────────────────────────────────────────────┐
# │  ZERO-CODE INSTRUMENTATION                                  │
# │  OTel agent JARs are pre-installed in /opt/otel/.           │
# │  All OTel config (agent path, service name, exporter, etc.) │
# │  is injected via env-{env}.yaml at deploy time.             │
# │  This image is OTel-agnostic — it runs with or without it.  │
# └─────────────────────────────────────────────────────────────┘

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]

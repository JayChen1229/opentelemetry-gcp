# ============================================================
# Multi-stage Dockerfile for Java Spring Boot with
# OpenTelemetry Java Agent (zero-code instrumentation)
# ============================================================
# The OTel Java Agent is downloaded and injected at build time.
# No application code changes are required.
#
# All OTel configuration (service name, exporter, endpoint)
# is injected via CI/CD environment variables at deploy time.
# ============================================================

# ── Stage 1: Build the application ──
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /app
COPY pom.xml .
# Download dependencies first (layer caching)
RUN mvn dependency:go-offline -B

COPY src ./src
RUN mvn package -DskipTests -B

# ── Stage 2: Download OpenTelemetry Java Agent + GCP Exporter ──
FROM curlimages/curl:latest AS otel-agent

# Download the Java Agent
RUN curl -L -o /tmp/opentelemetry-javaagent.jar \
    "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar"

# Download the Google Cloud Trace exporter extension
# This extension auto-detects GCP credentials (ADC) on Cloud Run
# and enables direct export to Cloud Trace / Cloud Monitoring
RUN curl -L -o /tmp/gcp-exporter.jar \
    "https://github.com/GoogleCloudPlatform/opentelemetry-operations-java/releases/latest/download/exporter-auto.jar"

# ── Stage 3: Runtime ──
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Copy application JAR
COPY --from=build /app/target/*.jar /app/app.jar

# Copy OTel Java Agent + GCP Exporter Extension
COPY --from=otel-agent /tmp/opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar
COPY --from=otel-agent /tmp/gcp-exporter.jar /otel/gcp-exporter.jar

# ┌─────────────────────────────────────────────────────────────┐
# │  ZERO-CODE INSTRUMENTATION                                  │
# │  Only the agent path is set here.                           │
# │  All other OTel config (service name, exporter, endpoint)   │
# │  is injected by CI/CD at deploy time.                       │
# └─────────────────────────────────────────────────────────────┘
ENV JAVA_TOOL_OPTIONS="-javaagent:/otel/opentelemetry-javaagent.jar -Dotel.javaagent.extensions=/otel/gcp-exporter.jar"

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]

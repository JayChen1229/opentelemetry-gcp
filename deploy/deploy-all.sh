#!/usr/bin/env bash
# ============================================================
# deploy-all.sh — 一鍵部署三個 Demo App 到 Cloud Run
# ============================================================
# Usage:
#   ./deploy/deploy-all.sh <PROJECT_ID> [REGION]
#
# What it does:
#   1. Build all three Docker images locally
#   2. Push images to Artifact Registry
#   3. Deploy each service to Cloud Run with OTel env vars
#
# This is the local equivalent of `cloudbuild-all.yaml`.
# ============================================================
set -euo pipefail

# ── Args ───────────────────────────────────────────────────
PROJECT_ID="${1:?Usage: $0 <PROJECT_ID> [REGION]}"
REGION="${2:-asia-east1}"
REPO_NAME="otel-demo"
REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}"
TAG=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
SA_EMAIL="otel-app-runtime@${PROJECT_ID}.iam.gserviceaccount.com"

# ── Resolve project root (one level up from deploy/) ──────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "══════════════════════════════════════════════════"
echo "  Deploying OTel demo apps to Cloud Run"
echo "══════════════════════════════════════════════════"
echo "  Project  : ${PROJECT_ID}"
echo "  Region   : ${REGION}"
echo "  Registry : ${REGISTRY}"
echo "  Tag      : ${TAG}"
echo "══════════════════════════════════════════════════"
echo ""

# ── OTel env vars (all injected at deploy time) ───────────
# Java: uses GCP-native exporter (google_cloud_trace)
JAVA_OTEL_ENVS="OTEL_SERVICE_NAME=java-demo-app"
JAVA_OTEL_ENVS+=",OTEL_TRACES_EXPORTER=google_cloud_trace"
JAVA_OTEL_ENVS+=",OTEL_METRICS_EXPORTER=google_cloud_monitoring"
JAVA_OTEL_ENVS+=",OTEL_LOGS_EXPORTER=none"
JAVA_OTEL_ENVS+=",OTEL_RESOURCE_ATTRIBUTES=service.namespace=otel-demo"

# .NET: uses OTLP exporter (for future Collector)
DOTNET_OTEL_ENVS="OTEL_SERVICE_NAME=dotnet-demo-app"
DOTNET_OTEL_ENVS+=",OTEL_TRACES_EXPORTER=otlp"
DOTNET_OTEL_ENVS+=",OTEL_METRICS_EXPORTER=otlp"
DOTNET_OTEL_ENVS+=",OTEL_LOGS_EXPORTER=none"
DOTNET_OTEL_ENVS+=",OTEL_RESOURCE_ATTRIBUTES=service.namespace=otel-demo"

# Python: uses GCP-native exporter (gcp_trace)
PYTHON_OTEL_ENVS="OTEL_SERVICE_NAME=python-demo-app"
PYTHON_OTEL_ENVS+=",OTEL_TRACES_EXPORTER=gcp_trace"
PYTHON_OTEL_ENVS+=",OTEL_METRICS_EXPORTER=gcp_monitoring"
PYTHON_OTEL_ENVS+=",OTEL_LOGS_EXPORTER=none"
PYTHON_OTEL_ENVS+=",OTEL_RESOURCE_ATTRIBUTES=service.namespace=otel-demo"
PYTHON_OTEL_ENVS+=",OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED=true"

# ── Common deploy flags ───────────────────────────────────
DEPLOY_FLAGS=(
  --region="${REGION}"
  --project="${PROJECT_ID}"
  --platform=managed
  --port=8080
  --cpu=1
  --memory=512Mi
  --min-instances=0
  --max-instances=10
  --allow-unauthenticated
  --service-account="${SA_EMAIL}"
)

# ── Service definitions ───────────────────────────────────
declare -a SERVICES=("java-demo-app" "dotnet-demo-app" "python-demo-app")
declare -a DIRS=("java-app" "dotnet-app" "python-app")
declare -a OTEL_ENVS=("${JAVA_OTEL_ENVS}" "${DOTNET_OTEL_ENVS}" "${PYTHON_OTEL_ENVS}")

# ══════════════════════════════════════════════════════════
#  Step 1: Build all images
# ══════════════════════════════════════════════════════════
echo "🔨 Building Docker images..."
echo ""

for i in "${!SERVICES[@]}"; do
  svc="${SERVICES[$i]}"
  dir="${DIRS[$i]}"
  image="${REGISTRY}/${svc}"

  echo "   📦 Building ${svc}..."
  docker build \
    -t "${image}:${TAG}" \
    -t "${image}:latest" \
    "${PROJECT_ROOT}/${dir}"
  echo "   ✓ ${svc} built."
  echo ""
done

# ══════════════════════════════════════════════════════════
#  Step 2: Push all images
# ══════════════════════════════════════════════════════════
echo "🚀 Pushing images to Artifact Registry..."
echo ""

for i in "${!SERVICES[@]}"; do
  svc="${SERVICES[$i]}"
  image="${REGISTRY}/${svc}"

  echo "   📤 Pushing ${svc}..."
  docker push "${image}:${TAG}"
  docker push "${image}:latest"
  echo "   ✓ ${svc} pushed."
  echo ""
done

# ══════════════════════════════════════════════════════════
#  Step 3: Deploy all services to Cloud Run
# ══════════════════════════════════════════════════════════
echo "☁️  Deploying to Cloud Run..."
echo ""

for i in "${!SERVICES[@]}"; do
  svc="${SERVICES[$i]}"
  image="${REGISTRY}/${svc}:${TAG}"
  envs="${OTEL_ENVS[$i]}"

  echo "   🌐 Deploying ${svc}..."
  gcloud run deploy "${svc}" \
    --image="${image}" \
    --set-env-vars="${envs}" \
    "${DEPLOY_FLAGS[@]}"

  echo "   ✓ ${svc} deployed."
  echo ""
done

# ══════════════════════════════════════════════════════════
#  Done
# ══════════════════════════════════════════════════════════
echo "══════════════════════════════════════════════════"
echo "  ✅ All services deployed!"
echo "══════════════════════════════════════════════════"
echo ""

echo "  Service URLs:"
for svc in "${SERVICES[@]}"; do
  URL=$(gcloud run services describe "${svc}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}" \
    --format="value(status.url)" 2>/dev/null || echo "(pending)")
  echo "    ${svc}: ${URL}"
done

echo ""
echo "  Test with:"
echo "    curl \$(gcloud run services describe java-demo-app --region=${REGION} --format='value(status.url)')/hello/world"
echo "    curl \$(gcloud run services describe dotnet-demo-app --region=${REGION} --format='value(status.url)')/hello/world"
echo "    curl \$(gcloud run services describe python-demo-app --region=${REGION} --format='value(status.url)')/hello/world"
echo ""
echo "  View traces:"
echo "    https://console.cloud.google.com/traces?project=${PROJECT_ID}"
echo ""

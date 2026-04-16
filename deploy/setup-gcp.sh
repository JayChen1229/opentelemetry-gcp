#!/usr/bin/env bash
# ============================================================
# setup-gcp.sh — 一鍵設定 GCP 環境
# ============================================================
# Usage:
#   ./deploy/setup-gcp.sh <PROJECT_ID> [REGION]
#
# What it does:
#   1. Enable required GCP APIs
#   2. Create Artifact Registry repository
#   3. Create Cloud Run service account with OTel permissions
#   4. Grant Cloud Build IAM roles
#   5. Configure Docker authentication
#
# Note: This script does the same thing as the Terraform module
#       in terraform/modules/gcp-otel-project. Use one or the
#       other, not both.
# ============================================================
set -euo pipefail

# ── Args ───────────────────────────────────────────────────
PROJECT_ID="${1:?Usage: $0 <PROJECT_ID> [REGION]}"
REGION="${2:-asia-east1}"
REPO_NAME="otel-demo"
SA_NAME="otel-app-runtime"

echo "══════════════════════════════════════════════════"
echo "  Setting up GCP environment for OTel demo"
echo "══════════════════════════════════════════════════"
echo "  Project : ${PROJECT_ID}"
echo "  Region  : ${REGION}"
echo "  Repo    : ${REPO_NAME}"
echo "══════════════════════════════════════════════════"
echo ""

# ── Step 1: Set project ────────────────────────────────────
echo "🔧 Setting active project to ${PROJECT_ID}..."
gcloud config set project "${PROJECT_ID}"

# ── Step 2: Enable APIs ───────────────────────────────────
echo ""
echo "📦 Enabling required GCP APIs..."
APIS=(
  run.googleapis.com
  cloudbuild.googleapis.com
  artifactregistry.googleapis.com
  cloudtrace.googleapis.com
  monitoring.googleapis.com
  logging.googleapis.com
  iam.googleapis.com
  cloudresourcemanager.googleapis.com
)

for api in "${APIS[@]}"; do
  echo "   ✓ ${api}"
done

gcloud services enable "${APIS[@]}" --project="${PROJECT_ID}"

# ── Step 3: Create Artifact Registry ──────────────────────
echo ""
echo "🐳 Creating Artifact Registry repository '${REPO_NAME}'..."

if gcloud artifacts repositories describe "${REPO_NAME}" \
     --location="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
  echo "   ⏭  Repository already exists, skipping."
else
  gcloud artifacts repositories create "${REPO_NAME}" \
    --repository-format=docker \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --description="Container images for OTel demo apps"
  echo "   ✓ Created."
fi

# ── Step 4: Create Service Account for Cloud Run apps ─────
echo ""
echo "👤 Creating service account '${SA_NAME}'..."

SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "${SA_EMAIL}" \
     --project="${PROJECT_ID}" &>/dev/null; then
  echo "   ⏭  Service account already exists, skipping."
else
  gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="OTel App Runtime Service Account" \
    --description="Service account for Cloud Run apps to send traces, metrics, and logs" \
    --project="${PROJECT_ID}"
  echo "   ✓ Created."
fi

# ── Step 5: Grant OTel-related IAM roles to SA ────────────
echo ""
echo "🔑 Granting IAM roles to ${SA_EMAIL}..."

APP_ROLES=(
  roles/cloudtrace.agent
  roles/monitoring.metricWriter
  roles/logging.logWriter
)

for role in "${APP_ROLES[@]}"; do
  echo "   ✓ ${role}"
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="${role}" \
    --condition=None \
    --quiet &>/dev/null
done

# ── Step 6: Grant Cloud Build roles ───────────────────────
echo ""
echo "🏗  Granting Cloud Build IAM roles..."

PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

CB_ROLES=(
  roles/run.admin
  roles/iam.serviceAccountUser
  roles/artifactregistry.writer
)

for role in "${CB_ROLES[@]}"; do
  echo "   ✓ ${role} → Cloud Build SA"
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${CB_SA}" \
    --role="${role}" \
    --condition=None \
    --quiet &>/dev/null
done

# ── Step 7: Configure Docker auth ─────────────────────────
echo ""
echo "🔐 Configuring Docker authentication for Artifact Registry..."
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# ── Done ──────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════"
echo "  ✅ GCP environment setup complete!"
echo "══════════════════════════════════════════════════"
echo ""
echo "  Artifact Registry : ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}"
echo "  App Runtime SA    : ${SA_EMAIL}"
echo "  Cloud Build SA    : ${CB_SA}"
echo ""
echo "  Next steps:"
echo "    ./deploy/deploy-all.sh ${PROJECT_ID} ${REGION}"
echo "    # or"
echo "    gcloud builds submit --config=cloudbuild-all.yaml \\"
echo "      --project=${PROJECT_ID} \\"
echo "      --substitutions=SHORT_SHA=\$(git rev-parse --short HEAD)"
echo ""

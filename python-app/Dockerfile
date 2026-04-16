# ============================================================
# Dockerfile for Python Flask with
# OpenTelemetry Auto-Instrumentation (zero-code)
# ============================================================
# The OTel packages + GCP exporters are pip-installed at build
# time. The `opentelemetry-instrument` CLI wraps the app
# startup command to automatically patch all supported libs.
# No application code changes are required.
#
# All OTel configuration (service name, exporter, endpoint)
# is injected via CI/CD environment variables at deploy time.
# ============================================================

FROM python:3.12-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt requirements-otel.txt ./
RUN pip install --no-cache-dir -r requirements.txt -r requirements-otel.txt && \
    opentelemetry-bootstrap -a install

# Copy application code
COPY . .

# ┌─────────────────────────────────────────────────────────────┐
# │  ZERO-CODE INSTRUMENTATION                                  │
# │  `opentelemetry-instrument` wraps the startup command.      │
# │  All OTel config (service name, exporter, endpoint) is      │
# │  injected by CI/CD at deploy time — not hardcoded here.     │
# └─────────────────────────────────────────────────────────────┘

# NOTE: OTEL_SERVICE_NAME, OTEL_TRACES_EXPORTER, etc.
# are NOT set here. They are injected by CI/CD at deploy time.

EXPOSE 8080

# Use opentelemetry-instrument to wrap gunicorn — zero code changes
CMD ["opentelemetry-instrument", "gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "120", "app:app"]

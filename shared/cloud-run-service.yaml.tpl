# Cloud Run Service YAML Template (for gcloud run services replace)
# ─────────────────────────────────────────────────────────
# This template is for reference / advanced use cases.
# For simple deployments, use `gcloud run deploy` instead
# (which is what the cloudbuild.yaml files do).
#
# When migrating to a centralized Collector (10+ services),
# add the sidecar container back and change
# OTEL_EXPORTER_OTLP_ENDPOINT to http://localhost:4317.
# ─────────────────────────────────────────────────────────
#
# Required variables (replace before applying):
#   ${SERVICE_NAME}         - Cloud Run service name
#   ${IMAGE_URI}            - Application container image URI
#   ${REGION}               - GCP Region
#   ${OTEL_SERVICE_NAME}    - OTel service name
#   ${OTEL_TRACES_EXPORTER} - Exporter name (google_cloud_trace / gcp_trace / otlp)
#   ${OTEL_METRICS_EXPORTER}- Exporter name (google_cloud_monitoring / gcp_monitoring / otlp)

apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${SERVICE_NAME}
  labels:
    cloud.googleapis.com/location: ${REGION}
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "0"
        autoscaling.knative.dev/maxScale: "10"
    spec:
      containerConcurrency: 80
      timeoutSeconds: 300
      containers:
        # ── Application Container (with OTel agent baked in) ──
        - name: app
          image: ${IMAGE_URI}
          ports:
            - name: http1
              containerPort: 8080
          env:
            # All OTel config is here, NOT in the Dockerfile.
            # Change these to reconfigure without rebuilding images.
            - name: OTEL_SERVICE_NAME
              value: "${OTEL_SERVICE_NAME}"
            - name: OTEL_TRACES_EXPORTER
              value: "${OTEL_TRACES_EXPORTER}"
            - name: OTEL_METRICS_EXPORTER
              value: "${OTEL_METRICS_EXPORTER}"
            - name: OTEL_LOGS_EXPORTER
              value: "none"
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "service.namespace=otel-demo"
            - name: OTEL_TRACES_SAMPLER
              value: "parentbased_traceidratio"
            - name: OTEL_TRACES_SAMPLER_ARG
              value: "1.0"
          resources:
            limits:
              cpu: "1"
              memory: 512Mi
          startupProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 3
            failureThreshold: 10

        # ── (Future) OTel Collector Sidecar ──
        # Uncomment when scaling to 10+ services or needing multi-backend.
        # Then change OTEL_TRACES_EXPORTER to "otlp" and
        # add OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
        #
        # - name: otel-collector
        #   image: us-docker.pkg.dev/cloud-ops-agents-artifacts/cloud-run-otel-sidecar/cloud-run-otel-sidecar:latest
        #   resources:
        #     limits:
        #       cpu: 500m
        #       memory: 256Mi

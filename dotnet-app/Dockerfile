# ============================================================
# Multi-stage Dockerfile for ASP.NET Core with
# OpenTelemetry .NET Auto-Instrumentation (zero-code)
# ============================================================
# The OTel .NET Auto-Instrumentation package is installed at
# build time. CLR Profiler environment variables enable
# automatic instrumentation without any code changes.
#
# All OTel configuration (service name, exporter, endpoint)
# is injected via CI/CD environment variables at deploy time.
# ============================================================

# ── Stage 1: Build the application ──
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /src
COPY DemoApp.csproj .
RUN dotnet restore

COPY . .
RUN dotnet publish -c Release -o /app/out

# ── Stage 2: Runtime with OTel Auto-Instrumentation ──
FROM mcr.microsoft.com/dotnet/aspnet:8.0

WORKDIR /app
COPY --from=build /app/out .

# Install dependencies for OTel auto-instrumentation
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl unzip && \
    rm -rf /var/lib/apt/lists/*

# Download and install OTel .NET Auto-Instrumentation
ARG OTEL_DOTNET_VERSION=1.9.0
RUN curl -L -o /tmp/otel-dotnet-install.sh \
    "https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/download/v${OTEL_DOTNET_VERSION}/otel-dotnet-auto-install.sh" && \
    chmod +x /tmp/otel-dotnet-install.sh && \
    OTEL_DOTNET_AUTO_HOME="/otel" sh /tmp/otel-dotnet-install.sh && \
    rm /tmp/otel-dotnet-install.sh

# ┌─────────────────────────────────────────────────────────────┐
# │  ZERO-CODE INSTRUMENTATION                                  │
# │  Only the CLR Profiler wiring is set here (agent path).     │
# │  All other OTel config (service name, exporter, endpoint)   │
# │  is injected by CI/CD at deploy time.                       │
# └─────────────────────────────────────────────────────────────┘
ENV CORECLR_ENABLE_PROFILING=1
ENV CORECLR_PROFILER="{918728DD-259F-4A6A-AC2B-B85E1B658318}"
ENV CORECLR_PROFILER_PATH="/otel/linux-x64/OpenTelemetry.AutoInstrumentation.Native.so"
ENV DOTNET_ADDITIONAL_DEPS="/otel/AdditionalDeps"
ENV DOTNET_SHARED_STORE="/otel/store"
ENV DOTNET_STARTUP_HOOKS="/otel/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll"
ENV OTEL_DOTNET_AUTO_HOME="/otel"
ENV ASPNETCORE_URLS="http://+:8080"

# NOTE: OTEL_SERVICE_NAME, OTEL_EXPORTER_OTLP_ENDPOINT, etc.
# are NOT set here. They are injected by CI/CD at deploy time.

EXPOSE 8080

ENTRYPOINT ["dotnet", "DemoApp.dll"]

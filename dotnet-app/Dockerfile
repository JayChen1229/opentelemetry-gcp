# ============================================================
# Multi-stage Dockerfile for ASP.NET Core with
# OpenTelemetry NuGet packages
# ============================================================

# ── Stage 1: Build ──
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /src
COPY DemoApp.csproj .
RUN dotnet restore

COPY . .
RUN dotnet publish -c Release -o /app/out

# ── Stage 2: Runtime ──
FROM mcr.microsoft.com/dotnet/aspnet:8.0

USER root
WORKDIR /app
COPY --from=build /app/out .

# 微軟 .NET 8 內建名為 `app` 的非特權使用者 (UID 1654)
RUN chown -R 1654:1654 /app

# 切換為安全非特權使用者
USER 1654

EXPOSE 8080

ENTRYPOINT ["dotnet", "DemoApp.dll"]

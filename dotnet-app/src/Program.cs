// ============================================================
// Simple ASP.NET Core Minimal API
//
// ┌─────────────────────────────────────────────────────────────┐
// │  OpenTelemetry configuration using NuGet packages           │
// │  Data is exported via OTLP.                                 │
// └─────────────────────────────────────────────────────────────┘
// ============================================================

using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Logs;
using OpenTelemetry.ResourceDetectors.Gcp;

var builder = WebApplication.CreateBuilder(args);

// Configure OpenTelemetry
builder.Services
    .AddOpenTelemetry()
    .ConfigureResource(r => r
        .AddEnvironmentVariableDetector()  // 讀 OTEL_RESOURCE_ATTRIBUTES
        .AddTelemetrySdk()                 // 加上 SDK 版本資訊（選用）
        .AddGcpDetector())                 // 自動偵測 Cloud Run instance (faas.instance, cloud.platform 等)
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter())
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddRuntimeInstrumentation()
        .AddOtlpExporter())
    .WithLogging(l => l
        .AddOtlpExporter());

var app = builder.Build();

app.MapGet("/", () => new
{
    service = "dotnet-demo-app",
    message = "Hello from .NET Core! (auto-instrumented with OpenTelemetry)",
    timestamp = DateTime.UtcNow.ToString("o"),
    framework = "ASP.NET Core 8.0"
});

app.MapGet("/hello/{name}", (string name) =>
{
    // Simulate some work
    Thread.Sleep(50);

    return new
    {
        greeting = $"Hello, {name}! 👋",
        language = "C#",
        instrumentation = "zero-code (.NET CLR Profiler)"
    };
});

app.MapGet("/health", () => new { status = "healthy" });

app.Run();

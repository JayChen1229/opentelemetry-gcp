// ============================================================
// Simple ASP.NET Core Minimal API with cross-service tracing
//
// ┌─────────────────────────────────────────────────────────────┐
// │  OpenTelemetry configuration using NuGet packages           │
// │  Data is exported via OTLP.                                 │
// │                                                             │
// │  Distributed Trace Chain:                                   │
// │    Java /chain → .NET /chain → Python /chain                │
// └─────────────────────────────────────────────────────────────┘
// ============================================================

using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Logs;
using OpenTelemetry.Resources.Gcp;

var builder = WebApplication.CreateBuilder(args);

// Register HttpClient for downstream calls
builder.Services.AddHttpClient();

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
        instrumentation = "NuGet programmatic (with GCP Resource Detector)"
    };
});

// ── Distributed Trace Chain ──
// .NET receives from Java, then calls Python
app.MapGet("/chain", async (IHttpClientFactory httpClientFactory) =>
{
    var pythonAppUrl = Environment.GetEnvironmentVariable("PYTHON_APP_URL") ?? "";
    var pythonResponse = "";

    if (!string.IsNullOrEmpty(pythonAppUrl))
    {
        try
        {
            var client = httpClientFactory.CreateClient();
            pythonResponse = await client.GetStringAsync($"{pythonAppUrl}/chain");
        }
        catch (Exception e)
        {
            pythonResponse = $"Error calling Python: {e.Message}";
        }
    }
    else
    {
        pythonResponse = "PYTHON_APP_URL not configured";
    }

    return new
    {
        service = "dotnet-demo-app",
        step = "2/3 (middle of chain)",
        timestamp = DateTime.UtcNow.ToString("o"),
        downstream = pythonResponse
    };
});

app.MapGet("/health", () => new { status = "healthy" });

app.Run();

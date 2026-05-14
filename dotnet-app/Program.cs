// ============================================================
// Simple ASP.NET Core Minimal API
//
// ┌─────────────────────────────────────────────────────────────┐
// │  OpenTelemetry configuration using NuGet packages           │
// │  Data is exported via OTLP.                                 │
// └─────────────────────────────────────────────────────────────┘
// ============================================================

using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

// Configure OpenTelemetry
builder.Services
    .AddOpenTelemetry()
    .UseOtlpExporter()
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation())
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddRuntimeInstrumentation())
    .WithLogging();

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

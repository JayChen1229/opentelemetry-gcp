// ============================================================
// Simple ASP.NET Core Minimal API
//
// ┌─────────────────────────────────────────────────────────────┐
// │  NO OpenTelemetry code here!                                │
// │  Instrumentation is injected via .NET CLR Profiler          │
// │  environment variables set in the Dockerfile:               │
// │    CORECLR_ENABLE_PROFILING=1                               │
// │    CORECLR_PROFILER={918728DD-...}                          │
// │  The application code remains 100% business logic only.     │
// └─────────────────────────────────────────────────────────────┘
// ============================================================

var builder = WebApplication.CreateBuilder(args);
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

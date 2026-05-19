package com.example.demo;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;

import java.time.Instant;
import java.util.Map;

/**
 * Simple Spring Boot REST API with cross-service tracing.
 *
 * ┌─────────────────────────────────────────────────────┐
 * │  NO OpenTelemetry code here!                        │
 * │  Instrumentation is injected via:                   │
 * │    -javaagent:/otel/opentelemetry-javaagent.jar     │
 * │  set in the Dockerfile's JAVA_TOOL_OPTIONS env var. │
 * │                                                     │
 * │  Distributed Trace Chain:                           │
 * │    Java /chain → .NET /chain → Python /chain        │
 * │    (自動每 30 秒觸發一次)                              │
 * └─────────────────────────────────────────────────────┘
 */
@SpringBootApplication
@EnableScheduling
@RestController
public class DemoApp {

    @Value("${DOTNET_APP_URL:}")
    private String dotnetAppUrl;

    private final RestClient restClient = RestClient.create();

    public static void main(String[] args) {
        SpringApplication.run(DemoApp.class, args);
    }

    @GetMapping("/")
    public Map<String, Object> index() {
        return Map.of(
            "service", "java-demo-app",
            "message", "Hello from Java Spring Boot! (auto-instrumented with OpenTelemetry)",
            "timestamp", Instant.now().toString(),
            "framework", "Spring Boot 3.3"
        );
    }

    @GetMapping("/hello/{name}")
    public Map<String, String> hello(@PathVariable String name) {
        // Simulate some work
        try {
            Thread.sleep(50);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        return Map.of(
            "greeting", String.format("Hello, %s! 👋", name),
            "language", "Java",
            "instrumentation", "zero-code (Java Agent)"
        );
    }

    // ── Distributed Trace Chain ──
    // Java (SERVER span) → .NET (SERVER span) → Python (SERVER span)
    @GetMapping("/chain")
    public Map<String, Object> chain() {
        String dotnetResponse = "";

        if (!dotnetAppUrl.isEmpty()) {
            try {
                dotnetResponse = restClient.get()
                    .uri(dotnetAppUrl + "/chain")
                    .retrieve()
                    .body(String.class);
            } catch (Exception e) {
                dotnetResponse = "Error calling .NET: " + e.getMessage();
            }
        } else {
            dotnetResponse = "DOTNET_APP_URL not configured";
        }

        return Map.of(
            "service", "java-demo-app",
            "step", "1/3 (chain initiator)",
            "timestamp", Instant.now().toString(),
            "downstream", dotnetResponse
        );
    }

    // ── 自動觸發：每 30 秒呼叫一次 chain ──
    @Scheduled(fixedDelay = 30000, initialDelay = 10000)
    public void autoChain() {
        if (dotnetAppUrl.isEmpty()) {
            return;
        }
        try {
            chain();
        } catch (Exception e) {
            // Silently ignore — traces will still be generated for the attempt
        }
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "healthy");
    }
}

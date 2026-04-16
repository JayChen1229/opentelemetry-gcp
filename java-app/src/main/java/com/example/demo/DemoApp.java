package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

/**
 * Simple Spring Boot REST API.
 *
 * ┌─────────────────────────────────────────────────────┐
 * │  NO OpenTelemetry code here!                        │
 * │  Instrumentation is injected via:                   │
 * │    -javaagent:/otel/opentelemetry-javaagent.jar     │
 * │  set in the Dockerfile's JAVA_TOOL_OPTIONS env var. │
 * └─────────────────────────────────────────────────────┘
 */
@SpringBootApplication
@RestController
public class DemoApp {

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

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "healthy");
    }
}

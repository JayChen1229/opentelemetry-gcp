"""
Simple Flask REST API.

┌─────────────────────────────────────────────────────────────┐
│  NO OpenTelemetry code here!                                │
│  Instrumentation is injected via the                        │
│  `opentelemetry-instrument` CLI wrapper in the Dockerfile:  │
│    CMD ["opentelemetry-instrument", "gunicorn", ...]        │
│  The application code remains 100% business logic only.     │
└─────────────────────────────────────────────────────────────┘
"""

import datetime

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify(
        service="python-demo-app",
        message="Hello from Python Flask! (auto-instrumented with OpenTelemetry)",
        timestamp=datetime.datetime.utcnow().isoformat(),
        framework="Flask 3.x",
    )


@app.route("/hello/<name>")
def hello(name: str):
    import time
    # Simulate some work
    time.sleep(0.05)

    return jsonify(
        greeting=f"Hello, {name}! 👋",
        language="Python",
        instrumentation="zero-code (opentelemetry-instrument)",
    )


@app.route("/health")
def health():
    return jsonify(status="healthy")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

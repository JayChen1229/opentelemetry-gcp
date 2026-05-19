"""
Simple Flask REST API with cross-service tracing.

┌─────────────────────────────────────────────────────────────┐
│  NO OpenTelemetry code here!                                │
│  Instrumentation is injected via the                        │
│  `opentelemetry-instrument` CLI wrapper in the Dockerfile:  │
│    CMD ["opentelemetry-instrument", "gunicorn", ...]        │
│  The application code remains 100% business logic only.     │
│                                                             │
│  Distributed Trace Chain:                                   │
│    Java /chain → .NET /chain → Python /chain (terminal)     │
└─────────────────────────────────────────────────────────────┘
"""

import datetime
import os

import requests
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


# ── Distributed Trace Chain (Terminal) ──
# Python is the last service in the chain
@app.route("/chain")
def chain():
    import time
    # Simulate some work
    time.sleep(0.03)

    return jsonify(
        service="python-demo-app",
        step="3/3 (chain terminal)",
        timestamp=datetime.datetime.utcnow().isoformat(),
        message="End of distributed trace chain 🏁",
    )


@app.route("/health")
def health():
    return jsonify(status="healthy")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

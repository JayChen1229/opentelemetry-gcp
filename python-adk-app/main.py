import os
import time
from fastapi import FastAPI
from google.adk.cli.fast_api import get_fast_api_app

# ==============================================================
# 啟動 Google ADK 應用程式 (Zero-Code OTel 自動注入版)
# ==============================================================
app = get_fast_api_app(
    agents_dir=os.path.dirname(os.path.abspath(__file__)),
    web=True,
    trace_to_cloud=False,  # 把 ADK 內建的設為 False，全權交給 opentelemetry-instrument CLI 處理
)

# 新增一個測試 API，讓你可以打這個 endpoint 來看 trace
@app.get("/hello/{name}")
def say_hello(name: str):
    # 此 API 會被 opentelemetry-instrument 的 FastAPI plugin 自動擷取 Span
    time.sleep(0.1) 
    return {
        "message": f"Hello, {name}!",
        "source": "Google ADK Agent",
        "tracing": "zero-code"
    }

@app.get("/health")
def health():
    return {"status": "ok", "mode": "google-adk", "trace_to_cloud": False}

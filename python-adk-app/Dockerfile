FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt requirements-otel.txt ./
# Install dependencies and bootstrap opentelemetry automatically
RUN pip install --no-cache-dir -r requirements.txt -r requirements-otel.txt && \
    opentelemetry-bootstrap -a install

COPY . .

EXPOSE 8080

# 使用 opentelemetry-instrument CLI 來包裝啟動命令，這樣它才會讀取 OTEL_* 環境變數
CMD ["opentelemetry-instrument", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"]
# Use official lightweight Python image
FROM python:3.11-slim

# Prevent Python from writing .pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

# Set working directory
WORKDIR /app

# Install system dependencies (curl for health check)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY . .

# Create non-root user for least-privilege container execution
RUN useradd -m -u 10001 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose standard Cloud Run port
EXPOSE 8080

# Health check to ensure FastAPI responds
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Launch uvicorn listening on the Cloud Run PORT environment variable
CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT} --workers 2

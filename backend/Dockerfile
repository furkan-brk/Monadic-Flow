# backend/Dockerfile — ParallelPulse FastAPI backend
#
# Multi-stage not needed; slim image keeps things fast.
# web3 + ckzg build requires gcc on Linux — installed here.

FROM python:3.12-slim

LABEL org.opencontainers.image.title="parallelpulse-backend"
LABEL org.opencontainers.image.description="ParallelPulse FastAPI WebSocket relay"

WORKDIR /app

# System packages:
#   curl  — used by Docker healthcheck (GET /health)
#   gcc   — required to build ckzg (web3.py dependency) from source on Linux
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        gcc \
        g++ \
        libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies before copying source so Docker layer cache
# is invalidated only when requirements.txt changes, not on every code edit.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY app/ ./app/

EXPOSE 8000

# pydantic-settings reads env vars directly when .env is absent — no file needed.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

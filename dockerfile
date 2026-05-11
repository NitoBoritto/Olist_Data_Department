# ─────────────────────────────────────────────
#  Stage 1 — dependency builder
#  Compiles heavy C-extension wheels once so
#  the final image stays lean.
# ─────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# System libs needed to compile wheels
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        g++ \
        libpq-dev \
        unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --upgrade pip \
 && pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# ─────────────────────────────────────────────
#  Stage 2 — runtime image
# ─────────────────────────────────────────────
FROM python:3.11-slim AS runtime

# Labels (OCI standard)
LABEL org.opencontainers.image.title="olist-bi" \
      org.opencontainers.image.description="Olist Business Intelligence — FastAPI ML Serving" \
      org.opencontainers.image.source="https://github.com/${{ github.repository }}"

# Non-root user for security
RUN groupadd --gid 1001 appgroup \
 && useradd  --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

# Runtime system deps (ODBC driver for Azure SQL, spaCy model download)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgomp1 \
        unixodbc \
        curl \
        gnupg2 \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
       | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] \
       https://packages.microsoft.com/debian/12/prod bookworm main" \
       > /etc/apt/sources.list.d/mssql-release.list \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 \
    && rm -rf /var/lib/apt/lists/*

# Install pre-built wheels from builder stage
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/* \
 && rm -rf /wheels

WORKDIR /app

# Copy application source (preserves directory structure expected by imports)
COPY --chown=appuser:appgroup src/          ./src/
COPY --chown=appuser:appgroup requirements.txt .

# Pre-trained model artifacts are baked into the image.
# Override at runtime by mounting a volume:
#   -v /host/models:/app/src/serving/models
# The directory is created here so the mount point always exists.
RUN mkdir -p src/serving/models/sentiment_model

# Switch to non-root
USER appuser

# Expose the FastAPI port
EXPOSE 8000

# Health-check — hits the /health endpoint every 30 s
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Default env vars (override with --env or docker-compose)
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

# Entrypoint: uvicorn with graceful shutdown
CMD ["python", "-m", "uvicorn", "src.app.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "2", \
     "--timeout-keep-alive", "30"]

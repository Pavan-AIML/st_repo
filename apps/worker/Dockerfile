# syntax=docker/dockerfile:1.7

# ---------------------------------------------------------------------------
# Stage 1 — builder.
# ---------------------------------------------------------------------------
FROM python:3.11-slim-bookworm AS build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build

COPY requirements.txt ./
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip \
 && /opt/venv/bin/pip install -r requirements.txt

# ---------------------------------------------------------------------------
# Stage 2 — runtime.
# Distroless Python 3.11. Same hardening as api: no shell, non-root,
# read-only-FS compatible. Worker has no HTTP port — no EXPOSE needed.
# ---------------------------------------------------------------------------
FROM gcr.io/distroless/python3-debian12:nonroot

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH="/opt/venv/lib/python3.11/site-packages"

WORKDIR /app

COPY --from=build /opt/venv /opt/venv
COPY --chown=nonroot:nonroot main.py ./

# Worker is a long-running loop (BLPOP on Redis). No port, no server.
CMD ["main.py"]

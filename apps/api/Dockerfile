# syntax=docker/dockerfile:1.7

# ---------------------------------------------------------------------------
# Stage 1 — builder.
# Full Python image with pip. Installs deps into /opt/venv.
# Nothing from this stage reaches the final image except the venv.
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
# Distroless Python 3.11. No shell, no pip, no apt. Runs as UID 65532.
# Compatible with readOnlyRootFilesystem=true at the pod spec.
# ---------------------------------------------------------------------------
FROM gcr.io/distroless/python3-debian12:nonroot

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH="/opt/venv/lib/python3.11/site-packages"

WORKDIR /app

COPY --from=build /opt/venv /opt/venv
COPY --chown=nonroot:nonroot main.py ./

EXPOSE 8000

# Distroless entrypoint is /usr/bin/python3.11, so CMD args pass to Python.
CMD ["-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

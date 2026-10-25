import json
import logging
import os
import random
import time
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

load_dotenv()

# ---------------------------------------------------------------------------
# OpenTelemetry — exports traces to Tempo over OTLP HTTP.
# OTEL_EXPORTER_OTLP_ENDPOINT points at the Tempo OTLP receiver (set via env).
# ---------------------------------------------------------------------------

OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
if OTEL_ENDPOINT:
    resource = Resource.create({"service.name": "shoplite-api"})
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=f"{OTEL_ENDPOINT}/v1/traces"))
    )
    trace.set_tracer_provider(provider)

# ---------------------------------------------------------------------------
# Logging — structured JSON
# ---------------------------------------------------------------------------


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        return json.dumps(
            {
                "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
                "level": record.levelname,
                "msg": record.getMessage(),
            }
        )


handler = logging.StreamHandler()
handler.setFormatter(JsonFormatter())
logger = logging.getLogger("api")
logger.addHandler(handler)
logger.setLevel(logging.INFO)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://shoplite:shoplite@localhost:5432/shoplite",
)

# BAD_BUILD_ERROR_PCT — percentage (0–100) of /products requests that return
# HTTP 500. Set to 0 in prod; non-zero only to simulate a bad build so the
# Argo Rollouts canary analysis detects it and aborts. Wired from Helm value
# api.badBuildErrorPct (chart: templates/rollout-api.yaml).
BAD_BUILD_ERROR_PCT = int(os.getenv("BAD_BUILD_ERROR_PCT", "0"))

# ---------------------------------------------------------------------------
# Prometheus metrics
# ---------------------------------------------------------------------------

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP request count",
    ["method", "path", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "path"],
)

# ---------------------------------------------------------------------------
# DB engine (module-level so lifespan can close it)
# ---------------------------------------------------------------------------

engine = create_async_engine(DATABASE_URL, pool_pre_ping=True)
AsyncSession = async_sessionmaker(engine, expire_on_commit=False)

# ---------------------------------------------------------------------------
# Lifespan — create table on startup, dispose engine on shutdown
# ---------------------------------------------------------------------------


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS products (
                    id    SERIAL PRIMARY KEY,
                    name  TEXT        NOT NULL,
                    price NUMERIC(12, 2) NOT NULL
                )
                """
            )
        )
    logger.info("DB ready")
    yield
    await engine.dispose()
    logger.info("Engine disposed")


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(title="ShopLite API", lifespan=lifespan)

# Instrument FastAPI + SQLAlchemy — every request gets a span, every DB
# query gets a child span. Both export to Tempo when OTEL_ENDPOINT is set.
if OTEL_ENDPOINT:
    FastAPIInstrumentor.instrument_app(app)
    SQLAlchemyInstrumentor().instrument(engine=engine.sync_engine)

# ---------------------------------------------------------------------------
# Prometheus middleware
# ---------------------------------------------------------------------------


@app.middleware("http")
async def prometheus_middleware(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    latency = time.perf_counter() - start
    path = request.url.path
    REQUEST_COUNT.labels(method=request.method, path=path, status=response.status_code).inc()
    REQUEST_LATENCY.labels(method=request.method, path=path).observe(latency)
    return response


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class ProductIn(BaseModel):
    name: str
    price: float


class ProductOut(BaseModel):
    id: int
    name: str
    price: float

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@app.get("/healthz", tags=["ops"])
async def healthz():
    return {"status": "ok"}


@app.get("/readyz", tags=["ops"])
async def readyz():
    try:
        async with AsyncSession() as session:
            await session.execute(text("SELECT 1"))
        return {"status": "ok"}
    except Exception as exc:
        logger.info({"event": "readyz_fail", "error": str(exc)})
        return JSONResponse(status_code=503, content={"status": "unavailable"})


@app.get("/metrics", tags=["ops"])
async def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/products", response_model=list[ProductOut], tags=["products"])
async def list_products():
    if BAD_BUILD_ERROR_PCT > 0 and random.randint(1, 100) <= BAD_BUILD_ERROR_PCT:
        logger.info({"event": "injected_failure", "pct": BAD_BUILD_ERROR_PCT})
        raise HTTPException(status_code=500, detail="injected failure")
    async with AsyncSession() as session:
        result = await session.execute(text("SELECT id, name, price FROM products ORDER BY id"))
        rows = result.mappings().all()
    logger.info({"event": "list_products", "count": len(rows)})
    return [ProductOut(id=r["id"], name=r["name"], price=float(r["price"])) for r in rows]


@app.post("/products", response_model=ProductOut, status_code=201, tags=["products"])
async def create_product(body: ProductIn):
    async with AsyncSession() as session:
        result = await session.execute(
            text(
                "INSERT INTO products (name, price) VALUES (:name, :price) "
                "RETURNING id, name, price"
            ),
            {"name": body.name, "price": body.price},
        )
        row = result.mappings().one()
        await session.commit()
    logger.info({"event": "create_product", "id": row["id"]})
    return ProductOut(id=row["id"], name=row["name"], price=float(row["price"]))


@app.delete("/products/{product_id}", status_code=204, tags=["products"])
async def delete_product(product_id: int):
    async with AsyncSession() as session:
        result = await session.execute(
            text("DELETE FROM products WHERE id = :id RETURNING id"),
            {"id": product_id},
        )
        deleted = result.fetchone()
        await session.commit()
    if deleted is None:
        raise HTTPException(status_code=404, detail="Product not found")
    logger.info({"event": "delete_product", "id": product_id})

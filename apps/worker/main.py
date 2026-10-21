import asyncio
import json
import logging
import os

import asyncpg
import redis.asyncio as aioredis
from dotenv import load_dotenv

load_dotenv()

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://shoplite:shoplite@localhost:5432/shoplite"
)
QUEUE_KEY = "shoplite:jobs"

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger(__name__)


async def ensure_table(pg: asyncpg.Connection) -> None:
    await pg.execute(
        """
        CREATE TABLE IF NOT EXISTS job_results (
            id          SERIAL PRIMARY KEY,
            product_id  INT NOT NULL,
            processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )


async def handle_job(pg: asyncpg.Connection, raw: bytes) -> None:
    job = json.loads(raw)
    action = job.get("action")
    product_id = int(job["product_id"])

    if action == "log_product":
        await pg.execute(
            "INSERT INTO job_results (product_id) VALUES ($1)", product_id
        )
        log.info(
            json.dumps(
                {"event": "job_processed", "action": action, "product_id": product_id}
            )
        )
    else:
        log.info(
            json.dumps(
                {"event": "job_skipped", "reason": "unknown_action", "action": action}
            )
        )


async def main() -> None:
    pg = await asyncpg.connect(DATABASE_URL)
    await ensure_table(pg)

    while True:
        try:
            r = aioredis.from_url(REDIS_URL, decode_responses=False)
            log.info(json.dumps({"event": "worker_started", "queue": QUEUE_KEY}))

            async with r:
                while True:
                    result = await r.blpop(QUEUE_KEY, timeout=0)
                    if result is None:
                        continue
                    _, raw = result
                    try:
                        await handle_job(pg, raw)
                    except Exception as exc:
                        log.error(
                            json.dumps({"event": "job_error", "error": str(exc)})
                        )

        except (
            aioredis.ConnectionError,
            aioredis.TimeoutError,
            OSError,
        ) as exc:
            log.error(
                json.dumps(
                    {"event": "redis_error", "error": str(exc), "retry_in_s": 5}
                )
            )
            await asyncio.sleep(5)


if __name__ == "__main__":
    asyncio.run(main())

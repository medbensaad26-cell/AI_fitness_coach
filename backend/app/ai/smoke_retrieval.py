"""Verify retrieve_knowledge inside Docker after ingest.

    docker compose exec api python -m app.ai.smoke_retrieval
"""

from __future__ import annotations

import asyncio

from app.ai.retrieval import retrieve_knowledge
from app.db import async_session


async def _main() -> None:
    async with async_session() as db:
        hits = await retrieve_knowledge(
            db,
            "My knees hurt during squats, what should I change?",
            limit=3,
        )
    print("RETRIEVAL_OK", len(hits), "hits")
    for hit in hits:
        print(
            f"- dist={hit.distance:.4f} [{hit.category}/{hit.topic}] "
            f"{hit.content[:100]}..."
        )


if __name__ == "__main__":
    asyncio.run(_main())

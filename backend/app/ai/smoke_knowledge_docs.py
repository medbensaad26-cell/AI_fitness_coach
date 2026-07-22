"""Quick check after doc/exercise ingest.

    docker compose exec api python -m app.ai.smoke_knowledge_docs
"""

from __future__ import annotations

import asyncio

from sqlalchemy import func, select

from app.ai.retrieval import retrieve_knowledge
from app.db import async_session
from app.models.exercise import Exercise
from app.models.knowledge import KnowledgeChunk


async def _main() -> None:
    async with async_session() as db:
        exercises = await db.scalar(select(func.count()).select_from(Exercise))
        chunks = await db.scalar(select(func.count()).select_from(KnowledgeChunk))
        hits = await retrieve_knowledge(
            db,
            "How should I deload and manage training fatigue?",
            limit=3,
        )
        squat_hits = await retrieve_knowledge(
            db,
            "Romanian deadlift form cues and lower back safety",
            limit=3,
        )

    print("COUNTS", {"exercises": exercises, "knowledge_chunks": chunks})
    print("DELOAD_HITS")
    for hit in hits:
        print(f"- [{hit.category}/{hit.topic}] {hit.content[:120].replace(chr(10), ' ')}...")
    print("RDL_HITS")
    for hit in squat_hits:
        print(f"- [{hit.category}/{hit.topic}] {hit.content[:120].replace(chr(10), ' ')}...")


if __name__ == "__main__":
    asyncio.run(_main())

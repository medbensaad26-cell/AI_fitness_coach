"""Ingest fitness knowledge into knowledge_chunks (embed + store).

Run inside Docker::

    docker compose exec api python -m app.ai.ingest
"""

from __future__ import annotations

import asyncio
import uuid

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embeddings import embed_texts
from app.ai.knowledge_seed import KNOWLEDGE_SEEDS
from app.db import async_session
from app.models.knowledge import KnowledgeChunk

# Modest batches keep memory predictable inside the API container
_BATCH_SIZE = 8


async def ingest_knowledge(
    db: AsyncSession,
    *,
    replace: bool = False,
) -> dict[str, int]:
    """Embed seed texts and insert rows into knowledge_chunks.

    What: fills the RAG knowledge table.
    Why: retrieve_knowledge needs stored vectors to return tips.
    How: embed each seed with fastembed, then INSERT (optionally clearing first).
    """
    if replace:
        await db.execute(delete(KnowledgeChunk))
        await db.commit()

    existing = await db.scalar(select(func.count()).select_from(KnowledgeChunk))
    if existing and not replace:
        return {"inserted": 0, "skipped_existing": int(existing)}

    inserted = 0
    for start in range(0, len(KNOWLEDGE_SEEDS), _BATCH_SIZE):
        batch = KNOWLEDGE_SEEDS[start : start + _BATCH_SIZE]
        vectors = await embed_texts([item["content"] for item in batch])
        for seed, vector in zip(batch, vectors, strict=True):
            db.add(
                KnowledgeChunk(
                    id=uuid.uuid4(),
                    category=seed["category"],
                    topic=seed["topic"],
                    content=seed["content"],
                    embedding=vector,
                )
            )
            inserted += 1
        await db.commit()

    return {"inserted": inserted, "skipped_existing": 0}


async def _main() -> None:
    async with async_session() as db:
        result = await ingest_knowledge(db, replace=True)
    print("INGEST_OK", result)


if __name__ == "__main__":
    asyncio.run(_main())

"""Ingest trusted markdown docs (+ optional seed tips) into knowledge_chunks.

Run in Docker::

    docker compose exec api python -m app.ai.ingest_docs
"""

from __future__ import annotations

import asyncio
import uuid

from sqlalchemy import delete, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.doc_loader import load_trusted_doc_chunks
from app.ai.embeddings import embed_texts
from app.ai.knowledge_seed import KNOWLEDGE_SEEDS
from app.db import async_session
from app.models.knowledge import KnowledgeChunk

_BATCH_SIZE = 8


async def _embed_insert(
    db: AsyncSession,
    rows: list[tuple[str, str | None, str, str | None]],
) -> int:
    """rows: (category, topic, content, source)"""
    inserted = 0
    for start in range(0, len(rows), _BATCH_SIZE):
        batch = rows[start : start + _BATCH_SIZE]
        vectors = await embed_texts([r[2] for r in batch])
        for (category, topic, content, source), vector in zip(batch, vectors, strict=True):
            db.add(
                KnowledgeChunk(
                    id=uuid.uuid4(),
                    category=category,
                    topic=topic,
                    content=content,
                    source=source,
                    embedding=vector,
                )
            )
            inserted += 1
        await db.commit()
    return inserted


async def ingest_docs(
    db: AsyncSession,
    *,
    include_seeds: bool = True,
    replace_trusted: bool = True,
) -> dict[str, int]:
    """Load curated/external markdown into RAG. Does not touch raw documents/.

    What: expand knowledge_chunks from your trusted docs.
    Why: better grounding than the tiny hand-written seed alone.
    How: chunk markdown → fastembed → insert (optionally refresh seed tips too).
    """
    if replace_trusted:
        await db.execute(
            delete(KnowledgeChunk).where(
                or_(
                    KnowledgeChunk.source.is_(None),
                    KnowledgeChunk.source.like("documents/%"),
                    KnowledgeChunk.source == "seed",
                )
            )
        )
        await db.commit()

    rows: list[tuple[str, str | None, str, str | None]] = []

    if include_seeds:
        for seed in KNOWLEDGE_SEEDS:
            rows.append((seed["category"], seed["topic"], seed["content"], "seed"))

    doc_chunks = load_trusted_doc_chunks()
    for chunk in doc_chunks:
        rows.append((chunk.category, chunk.topic, chunk.content, chunk.source))

    inserted = await _embed_insert(db, rows)
    return {
        "inserted": inserted,
        "seeds": len(KNOWLEDGE_SEEDS) if include_seeds else 0,
        "doc_chunks": len(doc_chunks),
    }


async def _main() -> None:
    async with async_session() as db:
        result = await ingest_docs(db, include_seeds=True, replace_trusted=True)
    print("INGEST_DOCS_OK", result)


if __name__ == "__main__":
    asyncio.run(_main())

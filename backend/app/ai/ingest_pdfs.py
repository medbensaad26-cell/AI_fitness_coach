"""Ingest allowlisted science PDFs into knowledge_chunks.

Run in Docker::

    docker compose exec api python -m app.ai.ingest_pdfs
"""

from __future__ import annotations

import asyncio
import uuid

from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embeddings import embed_texts
from app.ai.pdf_loader import load_allowed_pdf_chunks
from app.db import async_session
from app.models.knowledge import KnowledgeChunk

_BATCH_SIZE = 8


async def ingest_pdfs(db: AsyncSession, *, replace: bool = True) -> dict[str, int]:
    """Embed selected PDFs only (skips Instagram/forum/raw noise)."""
    chunks = load_allowed_pdf_chunks()
    if replace:
        await db.execute(
            delete(KnowledgeChunk).where(
                KnowledgeChunk.source.like("raw documents/pdfs/%")
            )
        )
        await db.commit()

    inserted = 0
    for start in range(0, len(chunks), _BATCH_SIZE):
        batch = chunks[start : start + _BATCH_SIZE]
        vectors = await embed_texts([c.content for c in batch])
        for chunk, vector in zip(batch, vectors, strict=True):
            db.add(
                KnowledgeChunk(
                    id=uuid.uuid4(),
                    category=chunk.category,
                    topic=chunk.topic,
                    content=chunk.content,
                    source=chunk.source,
                    embedding=vector,
                )
            )
            inserted += 1
        await db.commit()

    return {"inserted": inserted, "files_chunked": len({c.source for c in chunks})}


async def _main() -> None:
    async with async_session() as db:
        result = await ingest_pdfs(db, replace=True)
    print("INGEST_PDFS_OK", result)


if __name__ == "__main__":
    asyncio.run(_main())

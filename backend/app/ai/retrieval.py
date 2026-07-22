"""Retrieve relevant fitness knowledge by vector similarity (RAG)."""

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embeddings import embed_text
from app.models.knowledge import KnowledgeChunk


@dataclass(frozen=True)
class RetrievedChunk:
    """Plain result B (or later AI services) can use without ORM coupling."""

    id: str
    category: str
    topic: str | None
    content: str
    distance: float


async def retrieve_knowledge(
    db: AsyncSession,
    query: str,
    *,
    limit: int = 5,
    category: str | None = None,
) -> list[RetrievedChunk]:
    """Find the knowledge chunks most similar to ``query``.

    How it works:
    1. Embed the query with the same model used at ingest time.
    2. Ask Postgres/pgvector for nearest neighbors (cosine distance).
    3. Return plain chunks the LLM can use as grounding context.

    ``distance`` is cosine distance: lower = more similar.
    """
    if not query.strip():
        return []

    query_vector = await embed_text(query)

    distance = KnowledgeChunk.embedding.cosine_distance(query_vector)
    stmt = select(KnowledgeChunk, distance.label("distance")).order_by(distance)

    if category:
        stmt = stmt.where(KnowledgeChunk.category == category)

    stmt = stmt.limit(limit)
    rows = await db.execute(stmt)

    results: list[RetrievedChunk] = []
    for chunk, dist in rows.all():
        results.append(
            RetrievedChunk(
                id=str(chunk.id),
                category=chunk.category,
                topic=chunk.topic,
                content=chunk.content,
                distance=float(dist),
            )
        )
    return results

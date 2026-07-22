"""Ingest exercise JSON catalog into exercises (+ optional RAG tip chunks).

Run in Docker::

    docker compose exec api python -m app.ai.ingest_exercises
"""

from __future__ import annotations

import asyncio
import uuid

from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embeddings import embed_texts
from app.ai.exercise_loader import (
    ExerciseRecord,
    exercise_to_rag_text,
    load_exercise_records,
)
from app.db import async_session
from app.models.exercise import Exercise
from app.models.knowledge import KnowledgeChunk

_BATCH_SIZE = 8


def _to_orm(record: ExerciseRecord) -> Exercise:
    return Exercise(
        id=record.id,
        name=record.name,
        aliases=record.aliases,
        pattern=record.pattern,
        type=record.type,
        mechanics=record.mechanics,
        force=record.force,
        primary_muscles=record.primary_muscles,
        secondary_muscles=record.secondary_muscles,
        equipment=record.equipment,
        difficulty=record.difficulty,
        instructions=record.instructions,
        form_cues=record.form_cues,
        contraindications=record.contraindications,
        regressions=record.regressions,
        progressions=record.progressions,
        safety_notes=record.safety_notes,
        common_mistakes=record.common_mistakes,
        source=record.source,
        scientific_confidence=record.scientific_confidence,
        row_uuid=uuid.uuid4(),
    )


async def ingest_exercises(
    db: AsyncSession,
    *,
    replace: bool = True,
    also_rag: bool = True,
) -> dict[str, int]:
    """Load exercises/*.json into the exercises table.

    What: canonical exercise catalog in Postgres.
    Why: generation can pick real exercises; not invent unsafe ones.
    How: validate JSON → upsert table; optionally embed coaching blurbs into RAG.
    """
    records = load_exercise_records()

    if replace:
        await db.execute(delete(Exercise))
        if also_rag:
            await db.execute(
                delete(KnowledgeChunk).where(KnowledgeChunk.source.like("exercise:%"))
            )
        await db.commit()

    for record in records:
        db.add(_to_orm(record))
    await db.commit()

    rag_inserted = 0
    if also_rag:
        rows = [
            ("exercise", record.pattern, exercise_to_rag_text(record), f"exercise:{record.id}")
            for record in records
        ]
        for start in range(0, len(rows), _BATCH_SIZE):
            batch = rows[start : start + _BATCH_SIZE]
            vectors = await embed_texts([r[2] for r in batch])
            for (category, topic, content, source), vector in zip(
                batch, vectors, strict=True
            ):
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
                rag_inserted += 1
            await db.commit()

    return {
        "exercises": len(records),
        "rag_chunks": rag_inserted,
    }


async def _main() -> None:
    async with async_session() as db:
        result = await ingest_exercises(db, replace=True, also_rag=True)
    print("INGEST_EXERCISES_OK", result)


if __name__ == "__main__":
    asyncio.run(_main())

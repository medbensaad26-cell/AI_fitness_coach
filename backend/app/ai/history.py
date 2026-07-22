"""Index finished sessions into per-user vector memory.

Person B should call ``index_session_history`` after saving a session.
"""

from __future__ import annotations

import uuid

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.chat import chat_completion
from app.ai.embeddings import embed_text
from app.ai.schemas import SessionSnapshot
from app.models.history import UserHistoryChunk


def build_session_facts(snapshot: SessionSnapshot) -> str:
    """Deterministic fact block from structured session fields.

    Why: always capture skipped/difficulty/fatigue even if the LLM call fails.
    """
    lines = [
        "Finished workout session facts:",
        f"- Overall feeling (1-5): {snapshot.overall_feeling}",
        f"- Fatigue (1-5): {snapshot.fatigue_level}",
        f"- Duration minutes: {snapshot.duration_minutes}",
        f"- Comments: {snapshot.comments or 'none'}",
        "- Exercises:",
    ]
    if not snapshot.exercises:
        lines.append("  (none logged)")
    for ex in snapshot.exercises:
        status = "SKIPPED" if ex.skipped else "done"
        lines.append(
            "  - "
            f"{ex.exercise_name} [{status}] "
            f"sets={ex.sets_completed} reps={ex.reps_completed} "
            f"weight_kg={ex.weight_kg} difficulty={ex.difficulty} "
            f"notes={ex.notes or 'none'}"
        )
    return "\n".join(lines)


async def summarize_session(snapshot: SessionSnapshot) -> str:
    """Turn session facts into a short coach memory paragraph via Groq.

    Falls back to the raw facts if the model call fails.
    """
    facts = build_session_facts(snapshot)
    try:
        summary = await chat_completion(
            [
                {
                    "role": "system",
                    "content": (
                        "You are a fitness coach writing a brief memory note for future "
                        "programming. In 4-8 sentences, summarize what happened, what was "
                        "skipped, how hard it felt, fatigue, and any constraints implied by "
                        "notes (pain, preference). Be factual. No markdown."
                    ),
                },
                {"role": "user", "content": facts},
            ],
            temperature=0.2,
            max_tokens=400,
        )
        return f"{summary.strip()}\n\n{facts}"
    except Exception:
        return facts


async def index_session_history(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    session_id: uuid.UUID,
    snapshot: SessionSnapshot,
) -> UserHistoryChunk:
    """Summarize a finished session, embed it, and store under that user only.

    What: personal workout memory for later retrieve / suggest-next.
    Why: global knowledge is not enough — adaptation needs this user's past.
    How: facts (+ Groq summary) → fastembed → user_history_chunks (1 row/session).
    """
    summary = await summarize_session(snapshot)
    vector = await embed_text(summary)

    await db.execute(
        delete(UserHistoryChunk).where(UserHistoryChunk.session_id == session_id)
    )

    chunk = UserHistoryChunk(
        id=uuid.uuid4(),
        user_id=user_id,
        session_id=session_id,
        category="session_summary",
        summary=summary,
        overall_feeling=snapshot.overall_feeling,
        fatigue_level=snapshot.fatigue_level,
        embedding=vector,
    )
    db.add(chunk)
    await db.commit()
    await db.refresh(chunk)
    return chunk


async def retrieve_user_history(
    db: AsyncSession,
    user_id: uuid.UUID,
    query: str,
    *,
    limit: int = 5,
) -> list[UserHistoryChunk]:
    """Nearest session memories for one user (never crosses user_id)."""
    if not query.strip():
        return []

    query_vector = await embed_text(query)
    distance = UserHistoryChunk.embedding.cosine_distance(query_vector)
    stmt = (
        select(UserHistoryChunk)
        .where(UserHistoryChunk.user_id == user_id)
        .order_by(distance)
        .limit(limit)
    )
    rows = await db.execute(stmt)
    return list(rows.scalars().all())


async def get_recent_user_history(
    db: AsyncSession,
    user_id: uuid.UUID,
    *,
    limit: int = 3,
) -> list[UserHistoryChunk]:
    """Most recent session memories for continuity (newest first)."""
    stmt = (
        select(UserHistoryChunk)
        .where(UserHistoryChunk.user_id == user_id)
        .order_by(UserHistoryChunk.created_at.desc())
        .limit(limit)
    )
    rows = await db.execute(stmt)
    return list(rows.scalars().all())

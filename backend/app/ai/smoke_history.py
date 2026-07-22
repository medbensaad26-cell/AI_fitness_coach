"""Smoke-test session history indexing inside Docker.

    docker compose exec api python -m app.ai.smoke_history
"""

from __future__ import annotations

import asyncio
import uuid
from datetime import datetime, timezone

from app.ai.history import index_session_history, retrieve_user_history
from app.ai.schemas import SessionExerciseSnapshot, SessionSnapshot
from app.core.security import hash_password
from app.db import async_session
from app.models.session import Session, SessionExercise
from app.models.user import User


async def _main() -> None:
    email = f"history-smoke-{uuid.uuid4().hex[:8]}@example.com"
    user_id = uuid.uuid4()
    session_id = uuid.uuid4()

    async with async_session() as db:
        db.add(
            User(
                id=user_id,
                email=email,
                hashed_password=hash_password("smoke-test-password"),
            )
        )
        db.add(
            Session(
                id=session_id,
                user_id=user_id,
                start_time=datetime.now(timezone.utc),
                end_time=datetime.now(timezone.utc),
                duration_minutes=42,
                overall_feeling=2,
                fatigue_level=5,
                comments="Left knee felt sore on lunges",
            )
        )
        db.add(
            SessionExercise(
                id=uuid.uuid4(),
                session_id=session_id,
                exercise_name="Walking Lunges",
                sets_completed=0,
                reps_completed=None,
                skipped=True,
                difficulty=None,
                notes="Skipped due to knee discomfort",
            )
        )
        db.add(
            SessionExercise(
                id=uuid.uuid4(),
                session_id=session_id,
                exercise_name="Goblet Squat",
                sets_completed=3,
                reps_completed="8",
                weight_kg=12,
                difficulty=4,
                skipped=False,
                notes="Controlled depth, knees ok",
            )
        )
        await db.commit()

        snapshot = SessionSnapshot(
            overall_feeling=2,
            fatigue_level=5,
            comments="Left knee felt sore on lunges",
            duration_minutes=42,
            exercises=[
                SessionExerciseSnapshot(
                    exercise_name="Walking Lunges",
                    sets_completed=0,
                    skipped=True,
                    notes="Skipped due to knee discomfort",
                ),
                SessionExerciseSnapshot(
                    exercise_name="Goblet Squat",
                    sets_completed=3,
                    reps_completed="8",
                    weight_kg=12,
                    difficulty=4,
                    skipped=False,
                    notes="Controlled depth, knees ok",
                ),
            ],
        )

        chunk = await index_session_history(
            db,
            user_id=user_id,
            session_id=session_id,
            snapshot=snapshot,
        )
        hits = await retrieve_user_history(
            db,
            user_id,
            "knee pain lunges fatigue next workout",
            limit=2,
        )

    print("HISTORY_INDEX_OK")
    print("chunk_id", chunk.id)
    print("summary_preview", chunk.summary[:280].replace("\n", " "))
    print("retrieve_hits", len(hits))
    for hit in hits:
        print("-", hit.summary[:160].replace("\n", " "))


if __name__ == "__main__":
    asyncio.run(_main())

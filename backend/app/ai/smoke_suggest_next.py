"""Smoke-test suggest_next after indexing a hard/fatigued session.

    docker compose exec api python -m app.ai.smoke_suggest_next
"""

from __future__ import annotations

import asyncio
import json
import uuid
from datetime import datetime

from app.ai.history import index_session_history
from app.ai.schemas import ProfileContext, SessionExerciseSnapshot, SessionSnapshot
from app.ai.suggest_next import suggest_next_program
from app.core.security import hash_password
from app.db import async_session
from app.models.session import Session, SessionExercise
from app.models.user import User


async def _main() -> None:
    email = f"suggest-smoke-{uuid.uuid4().hex[:8]}@example.com"
    user_id = uuid.uuid4()
    session_id = uuid.uuid4()

    profile = ProfileContext(
        name="Sam",
        age=30,
        sex="male",
        fitness_level="intermediate",
        primary_goal="build strength",
        training_frequency="4 days/week",
        available_equipment="dumbbells, bench, pull-up bar",
        limitations="history of left knee discomfort",
    )

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
                start_time=datetime.utcnow(),
                end_time=datetime.utcnow(),
                duration_minutes=50,
                overall_feeling=2,
                fatigue_level=5,
                comments="Very drained; left knee flared on lunges",
            )
        )
        db.add(
            SessionExercise(
                id=uuid.uuid4(),
                session_id=session_id,
                exercise_name="Walking Lunges",
                sets_completed=0,
                skipped=True,
                notes="Skipped — knee pain",
            )
        )
        db.add(
            SessionExercise(
                id=uuid.uuid4(),
                session_id=session_id,
                exercise_name="Barbell Back Squat",
                sets_completed=4,
                reps_completed="5",
                weight_kg=80,
                difficulty=5,
                skipped=False,
                notes="Heavy and grinding",
            )
        )
        await db.commit()

        await index_session_history(
            db,
            user_id=user_id,
            session_id=session_id,
            snapshot=SessionSnapshot(
                overall_feeling=2,
                fatigue_level=5,
                comments="Very drained; left knee flared on lunges",
                duration_minutes=50,
                exercises=[
                    SessionExerciseSnapshot(
                        exercise_name="Walking Lunges",
                        sets_completed=0,
                        skipped=True,
                        notes="Skipped — knee pain",
                    ),
                    SessionExerciseSnapshot(
                        exercise_name="Barbell Back Squat",
                        sets_completed=4,
                        reps_completed="5",
                        weight_kg=80,
                        difficulty=5,
                        skipped=False,
                        notes="Heavy and grinding",
                    ),
                ],
            ),
        )

        result = await suggest_next_program(db, profile, user_id)

    print("SUGGEST_NEXT_OK")
    print("rationale:", result.rationale)
    print("adaptations:", result.adaptations)
    print(json.dumps(result.program.model_dump(mode="json"), indent=2))


if __name__ == "__main__":
    asyncio.run(_main())

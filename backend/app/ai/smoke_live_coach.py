"""Smoke-test live coach turns in Docker.

    docker compose exec api python -m app.ai.smoke_live_coach
"""

from __future__ import annotations

import asyncio
import json

from app.ai.live_coach import (
    after_exercise_feedback,
    end_session_coach,
    mid_session_coach,
    start_session_check_in,
)
from app.ai.schemas import (
    AfterExerciseInput,
    EndSessionInput,
    MidSessionInput,
    PlannedExerciseContext,
    ProfileContext,
    SessionExerciseSnapshot,
)
from app.db import async_session


async def _main() -> None:
    profile = ProfileContext(
        name="Jordan",
        fitness_level="beginner",
        primary_goal="build strength",
        available_equipment="dumbbells",
        limitations="sensitive knees",
    )
    upcoming = [
        PlannedExerciseContext(exercise_name="Goblet Squat", sets=3, reps="8-10", order=0),
        PlannedExerciseContext(exercise_name="Romanian Deadlift", sets=3, reps="8-10", order=1),
    ]

    async with async_session() as db:
        start = await start_session_check_in(
            db, profile, program_name="Beginner Strength A", upcoming_exercises=upcoming
        )
        after = await after_exercise_feedback(
            db,
            profile,
            AfterExerciseInput(
                exercise_name="Goblet Squat",
                sets_completed=3,
                reps_completed="8",
                weight_kg=12,
                difficulty=4,
                skipped=False,
                notes="Slight knee pressure at the bottom",
                user_message="It hurt a little under the kneecap on the last set",
            ),
            planned=upcoming[0],
        )
        mid = await mid_session_coach(
            db,
            profile,
            MidSessionInput(
                user_message="My knee still feels weird — should I skip the next squat variation?",
                current_exercise=upcoming[0],
                upcoming_exercises=upcoming[1:],
                recent_feedback=[after.feedback],
                readiness=3,
            ),
        )

    end = await end_session_coach(
        profile,
        EndSessionInput(
            overall_feeling=3,
            fatigue_level=4,
            comments="Decent session but knee was nagging",
            duration_minutes=40,
            exercises=[
                after.feedback,
                SessionExerciseSnapshot(
                    exercise_name="Romanian Deadlift",
                    sets_completed=3,
                    reps_completed="8",
                    weight_kg=16,
                    difficulty=3,
                    skipped=False,
                    notes="Felt fine",
                ),
            ],
        ),
    )

    print("LIVE_COACH_OK")
    print("START:", start.message)
    print("START_PROMPTS:", [p.id for p in start.prompts])
    print("AFTER:", after.message)
    print("SAFETY_FLAG:", after.safety_flag)
    print("FEEDBACK:", json.dumps(after.feedback.model_dump(), indent=2))
    print("MID:", mid.message)
    print("MID_ACTION:", mid.suggested_action, "MID_SAFETY:", mid.safety_flag)
    print("END:", end.message)
    print(
        "SNAPSHOT_SCALES:",
        {
            "feeling": end.snapshot.overall_feeling,
            "fatigue": end.snapshot.fatigue_level,
            "exercises": len(end.snapshot.exercises),
        },
    )


if __name__ == "__main__":
    asyncio.run(_main())

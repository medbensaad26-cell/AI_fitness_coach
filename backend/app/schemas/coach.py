"""HTTP request bodies for live-coach routes (Person B → Person C)."""

import uuid

from pydantic import BaseModel, Field

from app.ai.schemas import (
    AfterExerciseInput,
    EndSessionInput,
    MidSessionInput,
    PlannedExerciseContext,
)


class CoachStartRequest(BaseModel):
    """Optional program context for the start-of-session check-in."""

    program_id: uuid.UUID | None = None
    program_name: str | None = None
    upcoming_exercises: list[PlannedExerciseContext] = Field(default_factory=list)


class CoachAfterExerciseRequest(AfterExerciseInput):
    """After-exercise payload plus optional program for planned sets/reps."""

    program_id: uuid.UUID | None = None


class CoachMidSessionRequest(MidSessionInput):
    """Free-form mid-session question (same shape as AI MidSessionInput)."""


class CoachEndRequest(EndSessionInput):
    """End-of-session check-in (same shape as AI EndSessionInput)."""

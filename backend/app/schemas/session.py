import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class SessionExerciseCreate(BaseModel):
    exercise_name: str
    sets_completed: int = Field(ge=0)
    reps_completed: str | None = None
    weight_kg: float | None = Field(default=None, ge=0)
    difficulty: int | None = Field(default=None, ge=1, le=5)
    skipped: bool = False
    notes: str | None = None


class SessionCreate(BaseModel):
    program_id: uuid.UUID | None = None
    start_time: datetime
    end_time: datetime | None = None
    overall_feeling: int | None = Field(default=None, ge=1, le=5)
    fatigue_level: int | None = Field(default=None, ge=1, le=5)
    comments: str | None = None
    exercises: list[SessionExerciseCreate] = []


class SessionExerciseResponse(BaseModel):
    id: uuid.UUID
    session_id: uuid.UUID
    exercise_name: str
    sets_completed: int
    reps_completed: str | None
    weight_kg: float | None
    difficulty: int | None
    skipped: bool
    notes: str | None

    model_config = {"from_attributes": True}


class SessionResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    program_id: uuid.UUID | None
    start_time: datetime
    end_time: datetime | None
    duration_minutes: int | None
    overall_feeling: int | None
    fatigue_level: int | None
    comments: str | None
    created_at: datetime
    exercises: list[SessionExerciseResponse]

    model_config = {"from_attributes": True}

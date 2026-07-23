import uuid
from datetime import date
from typing import Literal

from pydantic import BaseModel, Field


ProgramStatus = Literal["active", "completed", "archived"]


class ProgramExerciseCreate(BaseModel):
    exercise_name: str
    sets: int = Field(ge=1)
    reps: str
    rest_seconds: int | None = Field(default=None, ge=0)
    duration_minutes: int | None = Field(default=None, ge=0)
    notes: str | None = None
    order: int = Field(ge=0)


class ProgramCreate(BaseModel):
    name: str
    goal: str
    start_date: date
    end_date: date | None = None
    status: ProgramStatus = "active"
    exercises: list[ProgramExerciseCreate] = []


class ProgramGenerateRequest(BaseModel):
    """Optional overrides for AI program generation. Profile comes from the DB."""

    start_date: date | None = None


class ProgramSuggestNextRequest(BaseModel):
    """Optional overrides for suggest-next. History/profile come from the DB."""

    start_date: date | None = None


class ProgramExerciseResponse(BaseModel):
    id: uuid.UUID
    program_id: uuid.UUID
    exercise_name: str
    sets: int
    reps: str
    rest_seconds: int | None
    duration_minutes: int | None
    notes: str | None
    order: int

    model_config = {"from_attributes": True}


class ProgramResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    name: str
    goal: str
    start_date: date
    end_date: date | None
    status: str
    exercises: list[ProgramExerciseResponse]

    model_config = {"from_attributes": True}


class ProgramSuggestNextResponse(BaseModel):
    program: ProgramResponse
    rationale: str
    adaptations: list[str]

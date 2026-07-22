"""Inputs for AI coaching functions (plain data B can pass from DB rows)."""

from typing import Literal

from pydantic import BaseModel, Field


class ProfileContext(BaseModel):
    """Fitness profile fields used to personalize generation.

    Mirrors user_profiles columns Person B already stores — no ORM dependency.
    """

    name: str | None = None
    age: int | None = None
    sex: str | None = None
    height_cm: float | None = None
    weight_kg: float | None = None
    fitness_level: str | None = None
    primary_goal: str | None = None
    training_frequency: str | None = None
    available_equipment: str | None = None
    limitations: str | None = None


class GeneratedProgramExercise(BaseModel):
    exercise_name: str
    # Prefer catalog slug when available (e.g. romanian_deadlift)
    exercise_id: str | None = None
    sets: int = Field(ge=1)
    reps: str
    rest_seconds: int | None = Field(default=None, ge=0)
    duration_minutes: int | None = Field(default=None, ge=0)
    notes: str | None = None
    order: int = Field(ge=0)


class GeneratedProgram(BaseModel):
    """Structured workout matching what B persists via ProgramCreate."""

    name: str
    goal: str
    exercises: list[GeneratedProgramExercise] = Field(min_length=1)


class SessionExerciseSnapshot(BaseModel):
    """Exercise rows from a finished session (what B already stores)."""

    exercise_name: str
    sets_completed: int = Field(ge=0)
    reps_completed: str | None = None
    weight_kg: float | None = None
    difficulty: int | None = Field(default=None, ge=1, le=5)
    skipped: bool = False
    notes: str | None = None


class SessionSnapshot(BaseModel):
    """Finished session payload for history indexing (no ORM)."""

    overall_feeling: int | None = Field(default=None, ge=1, le=5)
    fatigue_level: int | None = Field(default=None, ge=1, le=5)
    comments: str | None = None
    duration_minutes: int | None = None
    exercises: list[SessionExerciseSnapshot] = Field(default_factory=list)


class SuggestNextResult(BaseModel):
    """Next session suggestion: saveable program + why we adapted."""

    program: GeneratedProgram
    rationale: str
    adaptations: list[str] = Field(default_factory=list)


# --- Live coach (in-session) ---

class PlannedExerciseContext(BaseModel):
    """Exercise from the active program (what the user is about to do / just did)."""

    exercise_name: str
    sets: int | None = None
    reps: str | None = None
    notes: str | None = None
    order: int | None = None


class CoachPrompt(BaseModel):
    """Structured question for the Flutter UI (or voice STT → these fields)."""

    id: str
    label: str
    input_type: Literal["scale", "text", "boolean"] = "scale"
    scale_min: int | None = None
    scale_max: int | None = None
    required: bool = True


class StartSessionResult(BaseModel):
    message: str
    prompts: list[CoachPrompt]


class AfterExerciseInput(BaseModel):
    """User answers after one exercise (typed or from voice→text)."""

    exercise_name: str
    sets_completed: int = Field(ge=0)
    reps_completed: str | None = None
    weight_kg: float | None = Field(default=None, ge=0)
    difficulty: int | None = Field(default=None, ge=1, le=5)
    skipped: bool = False
    notes: str | None = None
    user_message: str | None = None


class AfterExerciseResult(BaseModel):
    message: str
    feedback: SessionExerciseSnapshot
    safety_flag: bool = False
    prompts: list[CoachPrompt] = Field(default_factory=list)


class EndSessionInput(BaseModel):
    """Closing check-in answers from the user."""

    overall_feeling: int | None = Field(default=None, ge=1, le=5)
    fatigue_level: int | None = Field(default=None, ge=1, le=5)
    comments: str | None = None
    duration_minutes: int | None = None
    exercises: list[SessionExerciseSnapshot] = Field(default_factory=list)
    user_message: str | None = None


class EndSessionResult(BaseModel):
    message: str
    snapshot: SessionSnapshot
    prompts: list[CoachPrompt] = Field(default_factory=list)


class MidSessionInput(BaseModel):
    """Free-form mid-workout user message (typed or voice→text)."""

    user_message: str
    current_exercise: PlannedExerciseContext | None = None
    upcoming_exercises: list[PlannedExerciseContext] = Field(default_factory=list)
    recent_feedback: list[SessionExerciseSnapshot] = Field(default_factory=list)
    readiness: int | None = Field(default=None, ge=1, le=5)


class MidSessionResult(BaseModel):
    message: str
    safety_flag: bool = False
    suggested_action: Literal[
        "continue", "regress_exercise", "skip_exercise", "rest", "end_session"
    ] = "continue"
    prompts: list[CoachPrompt] = Field(default_factory=list)

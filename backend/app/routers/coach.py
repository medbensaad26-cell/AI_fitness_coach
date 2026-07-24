import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.ai.schemas import (
    AfterExerciseInput,
    AfterExerciseResult,
    EndSessionInput,
    EndSessionResult,
    MidSessionResult,
    PlannedExerciseContext,
    ProfileContext,
    StartSessionResult,
)
from app.core.deps import get_current_user
from app.db import get_db
from app.models.program import Program
from app.models.user import User, UserProfile
from app.schemas.coach import (
    CoachAfterExerciseRequest,
    CoachEndRequest,
    CoachMidSessionRequest,
    CoachStartRequest,
)

router = APIRouter(tags=["coach"])

# Fields ProfileContext exposes to the AI coach (must be present on the DB profile).
_REQUIRED_PROFILE_FIELDS = (
    "name",
    "age",
    "sex",
    "height_cm",
    "weight_kg",
    "fitness_level",
    "primary_goal",
    "training_frequency",
    "available_equipment",
    "limitations",
)


def _profile_to_context(profile: UserProfile) -> ProfileContext:
    missing = [
        field
        for field in _REQUIRED_PROFILE_FIELDS
        if getattr(profile, field, None) is None
    ]
    if missing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incomplete profile",
        )
    return ProfileContext(
        name=profile.name,
        age=profile.age,
        sex=profile.sex,
        height_cm=profile.height_cm,
        weight_kg=profile.weight_kg,
        fitness_level=profile.fitness_level,
        primary_goal=profile.primary_goal,
        training_frequency=profile.training_frequency,
        available_equipment=profile.available_equipment,
        limitations=profile.limitations,
    )


async def _load_user_with_profile(db: AsyncSession, user_id: uuid.UUID) -> User:
    result = await db.execute(
        select(User)
        .options(selectinload(User.profile))
        .where(User.id == user_id)
    )
    return result.scalar_one()


async def _require_profile_context(
    db: AsyncSession,
    current_user: User,
) -> ProfileContext:
    user = await _load_user_with_profile(db, current_user.id)
    if user.profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )
    return _profile_to_context(user.profile)


async def _load_owned_program(
    db: AsyncSession,
    *,
    program_id: uuid.UUID,
    user_id: uuid.UUID,
) -> Program:
    result = await db.execute(
        select(Program)
        .options(selectinload(Program.exercises))
        .where(Program.id == program_id)
    )
    program = result.scalar_one_or_none()
    if program is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Program not found",
        )
    if program.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not allowed to access this program",
        )
    program.exercises.sort(key=lambda exercise: exercise.order)
    return program


def _planned_from_program(program: Program) -> list[PlannedExerciseContext]:
    return [
        PlannedExerciseContext(
            exercise_name=exercise.exercise_name,
            sets=exercise.sets,
            reps=exercise.reps,
            notes=exercise.notes,
            order=exercise.order,
        )
        for exercise in program.exercises
    ]


def _find_planned(
    program: Program,
    exercise_name: str,
) -> PlannedExerciseContext | None:
    for exercise in program.exercises:
        if exercise.exercise_name == exercise_name:
            return PlannedExerciseContext(
                exercise_name=exercise.exercise_name,
                sets=exercise.sets,
                reps=exercise.reps,
                notes=exercise.notes,
                order=exercise.order,
            )
    return None


@router.post(
    "/coach/start",
    response_model=StartSessionResult,
    summary="Start-of-session coach check-in",
    description=(
        "Opening coach turn before the first exercise. Returns a short message and "
        "structured prompts (readiness / pain). Optional program_id loads upcoming "
        "exercises from an owned program. Does not persist a session."
    ),
)
async def coach_start(
    payload: CoachStartRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        profile_context = await _require_profile_context(db, current_user)

        program_name = payload.program_name
        upcoming = list(payload.upcoming_exercises)

        if payload.program_id is not None:
            program = await _load_owned_program(
                db,
                program_id=payload.program_id,
                user_id=current_user.id,
            )
            program_name = program_name or program.name
            if not upcoming:
                upcoming = _planned_from_program(program)

        try:
            from app.ai.live_coach import start_session_check_in

            return await start_session_check_in(
                db,
                profile_context,
                program_name=program_name,
                upcoming_exercises=upcoming or None,
            )
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Coach start failed",
            ) from None
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to start coach check-in",
        ) from None


@router.post(
    "/coach/after-exercise",
    response_model=AfterExerciseResult,
    summary="After-exercise coach feedback",
    description=(
        "Coach turn after one exercise is logged. Returns advice, a feedback snapshot "
        "for the client to accumulate, optional safety_flag, and follow-up prompts. "
        "Does not persist session rows."
    ),
)
async def coach_after_exercise(
    payload: CoachAfterExerciseRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        profile_context = await _require_profile_context(db, current_user)

        planned: PlannedExerciseContext | None = None
        if payload.program_id is not None:
            program = await _load_owned_program(
                db,
                program_id=payload.program_id,
                user_id=current_user.id,
            )
            planned = _find_planned(program, payload.exercise_name)

        ai_input = AfterExerciseInput(
            exercise_name=payload.exercise_name,
            sets_completed=payload.sets_completed,
            reps_completed=payload.reps_completed,
            weight_kg=payload.weight_kg,
            difficulty=payload.difficulty,
            skipped=payload.skipped,
            notes=payload.notes,
            user_message=payload.user_message,
        )

        try:
            from app.ai.live_coach import after_exercise_feedback

            return await after_exercise_feedback(
                db,
                profile_context,
                ai_input,
                planned=planned,
            )
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="After-exercise coach failed",
            ) from None
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get after-exercise feedback",
        ) from None


@router.post(
    "/coach/mid-session",
    response_model=MidSessionResult,
    summary="Mid-session free-form coach",
    description=(
        "Answer a typed or voice→text question during the workout. Returns message, "
        "suggested_action for the UI, and optional safety_flag / prompts."
    ),
)
async def coach_mid_session(
    payload: CoachMidSessionRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        profile_context = await _require_profile_context(db, current_user)

        try:
            from app.ai.live_coach import mid_session_coach

            return await mid_session_coach(db, profile_context, payload)
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Mid-session coach failed",
            ) from None
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get mid-session coach reply",
        ) from None


@router.post(
    "/coach/end",
    response_model=EndSessionResult,
    summary="End-of-session coach wrap-up",
    description=(
        "Closing coach turn. Returns a message and a SessionSnapshot the client should "
        "map into POST /api/sessions (which indexes history). Does not persist itself."
    ),
)
async def coach_end(
    payload: CoachEndRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        profile_context = await _require_profile_context(db, current_user)

        ai_input = EndSessionInput(
            overall_feeling=payload.overall_feeling,
            fatigue_level=payload.fatigue_level,
            comments=payload.comments,
            duration_minutes=payload.duration_minutes,
            exercises=payload.exercises,
            user_message=payload.user_message,
        )

        try:
            from app.ai.live_coach import end_session_coach

            return await end_session_coach(profile_context, ai_input)
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="End-session coach failed",
            ) from None
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get end-session coach wrap-up",
        ) from None

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.ai.schemas import ProfileContext
from app.core.deps import get_current_user
from app.db import get_db
from app.models.program import Program, ProgramExercise
from app.models.session import Session
from app.models.user import User, UserProfile
from app.schemas.program import (
    ProgramCreate,
    ProgramGenerateRequest,
    ProgramResponse,
    ProgramStatus,
    ProgramSuggestNextRequest,
    ProgramSuggestNextResponse,
)
from app.schemas.session import SessionResponse

router = APIRouter(tags=["programs"])

# Fields ProfileContext exposes to the AI generator (must be present on the DB profile).
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


def _program_from_create(user_id: uuid.UUID, payload: ProgramCreate) -> Program:
    return Program(
        user_id=user_id,
        name=payload.name,
        goal=payload.goal,
        start_date=payload.start_date,
        end_date=payload.end_date,
        status=payload.status,
        exercises=[
            ProgramExercise(
                exercise_name=exercise.exercise_name,
                sets=exercise.sets,
                reps=exercise.reps,
                rest_seconds=exercise.rest_seconds,
                duration_minutes=exercise.duration_minutes,
                notes=exercise.notes,
                order=exercise.order,
            )
            for exercise in payload.exercises
        ],
    )


async def _persist_program(
    db: AsyncSession,
    user_id: uuid.UUID,
    payload: ProgramCreate,
) -> Program:
    program = _program_from_create(user_id, payload)
    db.add(program)
    await db.commit()

    result = await db.execute(
        select(Program)
        .options(selectinload(Program.exercises))
        .where(Program.id == program.id)
    )
    created = result.scalar_one()
    created.exercises.sort(key=lambda exercise: exercise.order)
    return created


async def _load_user_with_profile(db: AsyncSession, user_id: uuid.UUID) -> User:
    result = await db.execute(
        select(User)
        .options(selectinload(User.profile))
        .where(User.id == user_id)
    )
    return result.scalar_one()


@router.post(
    "/programs/generate",
    response_model=ProgramResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Generate program with AI",
    description=(
        "Generate a workout program from the authenticated user's DB profile via AI, "
        "validate as ProgramCreate, persist under the JWT user, and return ProgramResponse."
    ),
)
async def generate_my_program(
    payload: ProgramGenerateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        user = await _load_user_with_profile(db, current_user.id)
        if user.profile is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profile not found",
            )

        profile_context = _profile_to_context(user.profile)

        try:
            from app.ai.generate_program import generate_program

            ai_result = await generate_program(
                db,
                profile_context,
                user_id=current_user.id,
                start_date=payload.start_date,
            )
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Program generation failed",
            ) from None

        try:
            program_create = ProgramCreate.model_validate(ai_result)
        except ValidationError:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Invalid program generated",
            ) from None

        return await _persist_program(db, current_user.id, program_create)
    except HTTPException:
        await db.rollback()
        raise
    except Exception:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create program",
        ) from None


@router.post(
    "/programs/suggest-next",
    response_model=ProgramSuggestNextResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Suggest next program with AI",
    description=(
        "Suggest and persist the next program using the authenticated user's indexed "
        "session history. Empty history is allowed. Returns program, rationale, and adaptations."
    ),
)
async def suggest_next_my_program(
    payload: ProgramSuggestNextRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        user = await _load_user_with_profile(db, current_user.id)
        if user.profile is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profile not found",
            )

        profile_context = _profile_to_context(user.profile)

        try:
            from app.ai.suggest_next import SuggestNextOutput, suggest_next_program

            ai_result = await suggest_next_program(
                db,
                profile_context,
                current_user.id,
                start_date=payload.start_date,
            )
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Program suggestion failed",
            ) from None

        if not isinstance(ai_result, SuggestNextOutput):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Invalid program suggestion",
            )

        try:
            program_create = ProgramCreate.model_validate(ai_result.program)
        except ValidationError:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Invalid program suggestion",
            ) from None

        rationale = (ai_result.rationale or "").strip() or (
            "Next session chosen from profile and available history."
        )
        adaptations = [
            item.strip()
            for item in (ai_result.adaptations or [])
            if isinstance(item, str) and item.strip()
        ]

        persisted = await _persist_program(db, current_user.id, program_create)
        return ProgramSuggestNextResponse(
            program=persisted,
            rationale=rationale,
            adaptations=adaptations,
        )
    except HTTPException:
        await db.rollback()
        raise
    except Exception:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create program",
        ) from None


@router.get(
    "/programs/{program_id}",
    response_model=ProgramResponse,
    summary="Get program by id",
    description="Return one program with ordered exercises. Owner-only (403 if not yours).",
)
async def get_program(
    program_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
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
    if program.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not allowed to access this program",
        )
    program.exercises.sort(key=lambda exercise: exercise.order)
    return program


@router.get("/me/programs", response_model=list[ProgramResponse])
async def list_my_programs(
    status_filter: ProgramStatus | None = Query(default=None, alias="status"),
    limit: int = Query(default=50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Program)
        .options(selectinload(Program.exercises))
        .where(Program.user_id == current_user.id)
        .order_by(Program.start_date.desc())
        .limit(limit)
    )
    if status_filter is not None:
        query = query.where(Program.status == status_filter)

    result = await db.execute(query)
    programs = result.scalars().all()
    for program in programs:
        program.exercises.sort(key=lambda exercise: exercise.order)
    return programs


@router.get(
    "/me/programs/{program_id}/sessions",
    response_model=list[SessionResponse],
)
async def list_program_sessions(
    program_id: uuid.UUID,
    limit: int = Query(default=50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Program).where(Program.id == program_id))
    program = result.scalar_one_or_none()
    if program is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Program not found",
        )
    if program.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not allowed to access this program",
        )

    result = await db.execute(
        select(Session)
        .options(selectinload(Session.exercises))
        .where(Session.program_id == program_id)
        .order_by(Session.start_time.desc())
        .limit(limit)
    )
    return result.scalars().all()


@router.post(
    "/programs",
    response_model=ProgramResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_program(
    payload: ProgramCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await _persist_program(db, current_user.id, payload)
    except HTTPException:
        await db.rollback()
        raise
    except Exception:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create program",
        ) from None

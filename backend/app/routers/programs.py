import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.db import get_db
from app.models.program import Program, ProgramExercise
from app.models.session import Session
from app.models.user import User
from app.schemas.program import ProgramCreate, ProgramResponse, ProgramStatus
from app.schemas.session import SessionResponse

router = APIRouter(tags=["programs"])


@router.get("/programs/{program_id}", response_model=ProgramResponse)
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
        program = Program(
            user_id=current_user.id,
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
    except HTTPException:
        await db.rollback()
        raise
    except Exception as exc:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create program",
        ) from exc

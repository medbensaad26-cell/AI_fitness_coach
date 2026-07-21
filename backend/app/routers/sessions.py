import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.db import get_db
from app.models.program import Program
from app.models.session import Session, SessionExercise
from app.models.user import User
from app.schemas.session import SessionCreate, SessionResponse

router = APIRouter(tags=["sessions"])


@router.get("/sessions/{session_id}", response_model=SessionResponse)
async def get_session(
    session_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Session)
        .options(selectinload(Session.exercises))
        .where(Session.id == session_id)
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found",
        )
    if session.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not allowed to access this session",
        )
    return session


@router.get("/me/sessions", response_model=list[SessionResponse])
async def list_my_sessions(
    limit: int = Query(default=50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Session)
        .options(selectinload(Session.exercises))
        .where(Session.user_id == current_user.id)
        .order_by(Session.start_time.desc())
        .limit(limit)
    )
    return result.scalars().all()


@router.post(
    "/sessions",
    response_model=SessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_session(
    payload: SessionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        if payload.program_id is not None:
            result = await db.execute(
                select(Program).where(Program.id == payload.program_id)
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
                    detail="Program does not belong to this user",
                )

        duration_minutes = None
        if payload.end_time is not None:
            duration_minutes = int(
                (payload.end_time - payload.start_time).total_seconds() // 60
            )

        session = Session(
            user_id=current_user.id,
            program_id=payload.program_id,
            start_time=payload.start_time,
            end_time=payload.end_time,
            duration_minutes=duration_minutes,
            overall_feeling=payload.overall_feeling,
            fatigue_level=payload.fatigue_level,
            comments=payload.comments,
            exercises=[
                SessionExercise(
                    exercise_name=exercise.exercise_name,
                    sets_completed=exercise.sets_completed,
                    reps_completed=exercise.reps_completed,
                    weight_kg=exercise.weight_kg,
                    difficulty=exercise.difficulty,
                    skipped=exercise.skipped,
                    notes=exercise.notes,
                )
                for exercise in payload.exercises
            ],
        )
        db.add(session)
        await db.commit()

        result = await db.execute(
            select(Session)
            .options(selectinload(Session.exercises))
            .where(Session.id == session.id)
        )
        return result.scalar_one()
    except HTTPException:
        await db.rollback()
        raise
    except Exception as exc:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create session",
        ) from exc

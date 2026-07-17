from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db import get_db
from app.models.session import Session, SessionExercise
from app.models.user import User
from app.schemas.session import SessionCreate, SessionResponse

router = APIRouter(tags=["sessions"])


@router.post(
    "/sessions",
    response_model=SessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_session(
    payload: SessionCreate, db: AsyncSession = Depends(get_db)
):
    try:
        result = await db.execute(select(User).where(User.id == payload.user_id))
        user = result.scalar_one_or_none()
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        duration_minutes = None
        if payload.end_time is not None:
            duration_minutes = int(
                (payload.end_time - payload.start_time).total_seconds() // 60
            )

        session = Session(
            user_id=payload.user_id,
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

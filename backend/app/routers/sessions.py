import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.ai.schemas import SessionExerciseSnapshot, SessionSnapshot
from app.core.deps import get_current_user
from app.db import get_db
from app.models.program import Program
from app.models.session import Session, SessionExercise
from app.models.user import User
from app.schemas.session import SessionCreate, SessionResponse

logger = logging.getLogger(__name__)

router = APIRouter(tags=["sessions"])


def _session_snapshot_from_orm(session: Session) -> SessionSnapshot:
    return SessionSnapshot(
        overall_feeling=session.overall_feeling,
        fatigue_level=session.fatigue_level,
        comments=session.comments,
        duration_minutes=session.duration_minutes,
        exercises=[
            SessionExerciseSnapshot(
                exercise_name=exercise.exercise_name,
                sets_completed=exercise.sets_completed,
                reps_completed=exercise.reps_completed,
                weight_kg=exercise.weight_kg,
                difficulty=exercise.difficulty,
                skipped=exercise.skipped,
                notes=exercise.notes,
            )
            for exercise in session.exercises
        ],
    )


async def _index_session_best_effort(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    session: Session,
) -> None:
    """Call AI history indexing after the session transaction has committed.

    Failures are logged only — they must not roll back or alter the saved session.
    ``index_session_history`` performs its own commit.
    """
    try:
        from app.ai.history import index_session_history

        await index_session_history(
            db,
            user_id=user_id,
            session_id=session.id,
            snapshot=_session_snapshot_from_orm(session),
        )
    except Exception:
        # Keep the request session usable / pool-safe after a failed AI commit.
        try:
            await db.rollback()
        except Exception:
            logger.exception(
                "Rollback after indexing failure also failed for session_id=%s",
                session.id,
            )
        logger.exception(
            "Session history indexing failed for session_id=%s user_id=%s",
            session.id,
            user_id,
        )


@router.get(
    "/sessions/{session_id}",
    response_model=SessionResponse,
    summary="Get session by id",
    description="Return one session with exercises. Owner-only.",
)
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


@router.get(
    "/me/sessions",
    response_model=list[SessionResponse],
    summary="List my sessions",
    description=(
        "List sessions for the authenticated user, newest start_time first. "
        "Optional query param limit (1–100, default 50)."
    ),
)
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
    summary="Create workout session",
    description=(
        "Persist a session and per-exercise completion for the JWT user. "
        "When program_id is set, the program must be owned by the caller and each "
        "exercise_name must exist on that program. After commit, best-effort "
        "index_session_history (indexing failure does not roll back the session)."
    ),
)
async def create_session(
    payload: SessionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        if payload.program_id is not None:
            result = await db.execute(
                select(Program)
                .options(selectinload(Program.exercises))
                .where(Program.id == payload.program_id)
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

            allowed_names = {exercise.exercise_name for exercise in program.exercises}
            for exercise in payload.exercises:
                if exercise.exercise_name not in allowed_names:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Exercise does not belong to this program",
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
        created = result.scalar_one()

        # Integration: index after successful commit so AI failures cannot roll back
        # the session. Duplicate POSTs intentionally create new session rows.
        await _index_session_best_effort(
            db, user_id=current_user.id, session=created
        )

        return created
    except HTTPException:
        await db.rollback()
        raise
    except Exception:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create session",
        ) from None

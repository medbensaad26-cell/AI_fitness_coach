import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Session(Base):
    __tablename__ = "sessions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    program_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("programs.id"), nullable=True, index=True
    )
    start_time: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    end_time: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    overall_feeling: Mapped[int | None] = mapped_column(Integer, nullable=True)
    fatigue_level: Mapped[int | None] = mapped_column(Integer, nullable=True)
    comments: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.utcnow
    )

    user: Mapped["User"] = relationship(back_populates="sessions")
    program: Mapped["Program | None"] = relationship(back_populates="sessions")
    exercises: Mapped[list["SessionExercise"]] = relationship(
        back_populates="session", cascade="all, delete-orphan"
    )


class SessionExercise(Base):
    __tablename__ = "session_exercises"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("sessions.id"), nullable=False, index=True
    )
    exercise_name: Mapped[str] = mapped_column(String, nullable=False)
    sets_completed: Mapped[int] = mapped_column(Integer, nullable=False)
    reps_completed: Mapped[str | None] = mapped_column(String, nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    difficulty: Mapped[int | None] = mapped_column(Integer, nullable=True)
    skipped: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    session: Mapped["Session"] = relationship(back_populates="exercises")

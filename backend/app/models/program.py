import uuid
from datetime import date

from sqlalchemy import Date, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Program(Base):
    __tablename__ = "programs"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String, nullable=False)
    goal: Mapped[str] = mapped_column(String, nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[str] = mapped_column(String, nullable=False, default="active")

    user: Mapped["User"] = relationship(back_populates="programs")
    exercises: Mapped[list["ProgramExercise"]] = relationship(
        back_populates="program", cascade="all, delete-orphan"
    )
    sessions: Mapped[list["Session"]] = relationship(back_populates="program")


class ProgramExercise(Base):
    __tablename__ = "program_exercises"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    program_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("programs.id"), nullable=False, index=True
    )
    exercise_name: Mapped[str] = mapped_column(String, nullable=False)
    sets: Mapped[int] = mapped_column(Integer, nullable=False)
    reps: Mapped[str] = mapped_column(String, nullable=False)
    rest_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    order: Mapped[int] = mapped_column("order", Integer, nullable=False)

    program: Mapped["Program"] = relationship(back_populates="exercises")

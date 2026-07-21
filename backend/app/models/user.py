import uuid
from datetime import date

from sqlalchemy import Date, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False, index=True)
    hashed_password: Mapped[str] = mapped_column(String, nullable=False)

    profile: Mapped["UserProfile | None"] = relationship(
        back_populates="user", uselist=False
    )
    sessions: Mapped[list["Session"]] = relationship(back_populates="user")
    programs: Mapped[list["Program"]] = relationship(back_populates="user")


class UserProfile(Base):
    __tablename__ = "user_profiles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), unique=True, nullable=False
    )
    name: Mapped[str | None] = mapped_column(String, nullable=True)
    age: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sex: Mapped[str | None] = mapped_column(String, nullable=True)
    height_cm: Mapped[float | None] = mapped_column(Float, nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    fitness_level: Mapped[str | None] = mapped_column(String, nullable=True)
    primary_goal: Mapped[str | None] = mapped_column(String, nullable=True)
    training_frequency: Mapped[str | None] = mapped_column(String, nullable=True)
    available_equipment: Mapped[str | None] = mapped_column(Text, nullable=True)
    limitations: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    updated_at: Mapped[date | None] = mapped_column(Date, nullable=True)

    user: Mapped["User"] = relationship(back_populates="profile")

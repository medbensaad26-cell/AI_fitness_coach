"""Per-user session history chunks for personalized RAG.

Separate from global knowledge_chunks so we never leak one user's history
to another. Person A defines; Person B owns the migration.
"""

import uuid
from datetime import datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.config import EMBEDDING_DIMENSIONS
from app.db import Base


class UserHistoryChunk(Base):
    """One embedded summary of a finished workout session for a single user."""

    __tablename__ = "user_history_chunks"
    __table_args__ = (
        UniqueConstraint("session_id", name="uq_user_history_chunks_session_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("sessions.id"), nullable=False, index=True
    )
    # Short label for debugging / filters (e.g. "session_summary")
    category: Mapped[str] = mapped_column(String(64), nullable=False, default="session_summary")
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    overall_feeling: Mapped[int | None] = mapped_column(Integer, nullable=True)
    fatigue_level: Mapped[int | None] = mapped_column(Integer, nullable=True)
    embedding: Mapped[list[float]] = mapped_column(
        Vector(EMBEDDING_DIMENSIONS), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

"""Fitness knowledge chunks stored for RAG retrieval.

Person A defines this schema; Person B owns applying the Alembic migration.
Later we will add a similar table for per-user history summaries.
"""

import uuid
from datetime import datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import DateTime, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.config import EMBEDDING_DIMENSIONS
from app.db import Base


class KnowledgeChunk(Base):
    """One piece of fitness knowledge with an embedding for similarity search.

    Example content: squat form cues, beginner progressive overload tips,
    knee-friendly alternatives, rest guidance, etc.
    """

    __tablename__ = "knowledge_chunks"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    # Short label for filtering / debugging (e.g. "form", "programming", "safety")
    category: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    # Optional topic tag (e.g. "squat", "fatigue", "beginner")
    topic: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    # Human-readable text the LLM will see after retrieval
    content: Mapped[str] = mapped_column(Text, nullable=False)
    # Provenance: seed | documents/... | exercise:<id>
    source: Mapped[str | None] = mapped_column(String(512), nullable=True, index=True)
    # Vector from the embedding provider — must match EMBEDDING_DIMENSIONS
    embedding: Mapped[list[float]] = mapped_column(
        Vector(EMBEDDING_DIMENSIONS), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

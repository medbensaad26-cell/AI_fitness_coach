"""Canonical exercise catalog (from knowledge_docs JSON).

Person A defines the schema from the JSON files; Person B owns the migration.
Program/session rows can keep free-text names for now; later they can FK here.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, Text, func
from sqlalchemy.dialects.postgresql import ARRAY, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Exercise(Base):
    __tablename__ = "exercises"

    # Stable slug from JSON "id" (e.g. romanian_deadlift)
    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    name: Mapped[str] = mapped_column(String(256), nullable=False, index=True)
    aliases: Mapped[list[str]] = mapped_column(ARRAY(String), nullable=False, default=list)
    pattern: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    type: Mapped[str] = mapped_column(String(64), nullable=False)
    mechanics: Mapped[str | None] = mapped_column(String(64), nullable=True)
    force: Mapped[str | None] = mapped_column(String(64), nullable=True)
    primary_muscles: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, default=list
    )
    secondary_muscles: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, default=list
    )
    equipment: Mapped[list[str]] = mapped_column(ARRAY(String), nullable=False, default=list)
    difficulty: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    instructions: Mapped[str] = mapped_column(Text, nullable=False)
    form_cues: Mapped[list[str]] = mapped_column(ARRAY(String), nullable=False, default=list)
    contraindications: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, default=list
    )
    regressions: Mapped[list[str]] = mapped_column(ARRAY(String), nullable=False, default=list)
    progressions: Mapped[list[str]] = mapped_column(ARRAY(String), nullable=False, default=list)
    safety_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    common_mistakes: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, default=list
    )
    source: Mapped[str | None] = mapped_column(Text, nullable=True)
    scientific_confidence: Mapped[str | None] = mapped_column(String(32), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    # Optional internal uuid if B later wants opaque IDs alongside slug PK
    row_uuid: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), default=uuid.uuid4, nullable=False, unique=True
    )

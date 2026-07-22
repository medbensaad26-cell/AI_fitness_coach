"""add exercises catalog and knowledge source

Revision ID: c5d6e7f8a9b0
Revises: b4c5d6e7f8a9
Create Date: 2026-07-22 10:45:00.000000

Proposed by Person A (AI/RAG). Person B owns reviewing and applying migrations.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "c5d6e7f8a9b0"
down_revision: Union[str, Sequence[str], None] = "b4c5d6e7f8a9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "knowledge_chunks",
        sa.Column("source", sa.String(length=512), nullable=True),
    )
    op.create_index(
        op.f("ix_knowledge_chunks_source"),
        "knowledge_chunks",
        ["source"],
        unique=False,
    )

    op.create_table(
        "exercises",
        sa.Column("id", sa.String(length=128), nullable=False),
        sa.Column("name", sa.String(length=256), nullable=False),
        sa.Column("aliases", postgresql.ARRAY(sa.String()), nullable=False),
        sa.Column("pattern", sa.String(length=64), nullable=False),
        sa.Column("type", sa.String(length=64), nullable=False),
        sa.Column("mechanics", sa.String(length=64), nullable=True),
        sa.Column("force", sa.String(length=64), nullable=True),
        sa.Column("primary_muscles", postgresql.ARRAY(sa.String()), nullable=False),
        sa.Column("secondary_muscles", postgresql.ARRAY(sa.String()), nullable=False),
        sa.Column("equipment", postgresql.ARRAY(sa.String()), nullable=False),
        sa.Column("difficulty", sa.String(length=32), nullable=True),
        sa.Column("instructions", sa.Text(), nullable=False),
        sa.Column("form_cues", postgresql.ARRAY(sa.String()), nullable=False),
        sa.Column("contraindications", postgresql.ARRAY(sa.String()), nullable=False),
        sa.Column("regressions", postgresql.ARRAY(sa.String()), nullable=False),
        sa.Column("progressions", postgresql.ARRAY(sa.String()), nullable=False),
        sa.Column("safety_notes", sa.Text(), nullable=True),
        sa.Column("common_mistakes", postgresql.ARRAY(sa.String()), nullable=False),
        sa.Column("source", sa.Text(), nullable=True),
        sa.Column("scientific_confidence", sa.String(length=32), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("row_uuid", sa.UUID(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("row_uuid"),
    )
    op.create_index(op.f("ix_exercises_name"), "exercises", ["name"], unique=False)
    op.create_index(op.f("ix_exercises_pattern"), "exercises", ["pattern"], unique=False)
    op.create_index(
        op.f("ix_exercises_difficulty"), "exercises", ["difficulty"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_exercises_difficulty"), table_name="exercises")
    op.drop_index(op.f("ix_exercises_pattern"), table_name="exercises")
    op.drop_index(op.f("ix_exercises_name"), table_name="exercises")
    op.drop_table("exercises")
    op.drop_index(op.f("ix_knowledge_chunks_source"), table_name="knowledge_chunks")
    op.drop_column("knowledge_chunks", "source")

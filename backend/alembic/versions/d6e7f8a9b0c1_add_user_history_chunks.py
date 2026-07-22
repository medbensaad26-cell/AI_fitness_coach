"""add user_history_chunks for session memory RAG

Revision ID: d6e7f8a9b0c1
Revises: c5d6e7f8a9b0
Create Date: 2026-07-22 10:55:00.000000

Proposed by Person A (AI/RAG). Person B owns reviewing and applying migrations.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from pgvector.sqlalchemy import Vector


revision: str = "d6e7f8a9b0c1"
down_revision: Union[str, Sequence[str], None] = "c5d6e7f8a9b0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

EMBEDDING_DIMENSIONS = 384


def upgrade() -> None:
    op.create_table(
        "user_history_chunks",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("session_id", sa.UUID(), nullable=False),
        sa.Column("category", sa.String(length=64), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("overall_feeling", sa.Integer(), nullable=True),
        sa.Column("fatigue_level", sa.Integer(), nullable=True),
        sa.Column("embedding", Vector(EMBEDDING_DIMENSIONS), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["session_id"], ["sessions.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("session_id", name="uq_user_history_chunks_session_id"),
    )
    op.create_index(
        op.f("ix_user_history_chunks_user_id"),
        "user_history_chunks",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_user_history_chunks_session_id"),
        "user_history_chunks",
        ["session_id"],
        unique=False,
    )
    op.execute(
        """
        CREATE INDEX ix_user_history_chunks_embedding_hnsw
        ON user_history_chunks
        USING hnsw (embedding vector_cosine_ops)
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_user_history_chunks_embedding_hnsw")
    op.drop_index(
        op.f("ix_user_history_chunks_session_id"), table_name="user_history_chunks"
    )
    op.drop_index(op.f("ix_user_history_chunks_user_id"), table_name="user_history_chunks")
    op.drop_table("user_history_chunks")

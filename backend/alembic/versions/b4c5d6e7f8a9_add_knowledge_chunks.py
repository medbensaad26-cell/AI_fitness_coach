"""add knowledge_chunks for RAG

Revision ID: b4c5d6e7f8a9
Revises: a3b8c9d1e2f4
Create Date: 2026-07-22 09:00:00.000000

Proposed by Person A (AI/RAG). Person B owns reviewing and applying migrations.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from pgvector.sqlalchemy import Vector


revision: str = "b4c5d6e7f8a9"
down_revision: Union[str, Sequence[str], None] = "a3b8c9d1e2f4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Must match app.core.config.EMBEDDING_DIMENSIONS (BAAI/bge-small-en-v1.5 = 384)
EMBEDDING_DIMENSIONS = 384


def upgrade() -> None:
    # Enable pgvector in this database (image already includes the extension files)
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        "knowledge_chunks",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("category", sa.String(length=64), nullable=False),
        sa.Column("topic", sa.String(length=128), nullable=True),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("embedding", Vector(EMBEDDING_DIMENSIONS), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_knowledge_chunks_category"),
        "knowledge_chunks",
        ["category"],
        unique=False,
    )
    op.create_index(
        op.f("ix_knowledge_chunks_topic"),
        "knowledge_chunks",
        ["topic"],
        unique=False,
    )
    # HNSW index: fast approximate nearest-neighbor search for cosine distance
    # (vector_cosine_ops matches .cosine_distance() in retrieval.py)
    op.execute(
        """
        CREATE INDEX ix_knowledge_chunks_embedding_hnsw
        ON knowledge_chunks
        USING hnsw (embedding vector_cosine_ops)
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_knowledge_chunks_embedding_hnsw")
    op.drop_index(op.f("ix_knowledge_chunks_topic"), table_name="knowledge_chunks")
    op.drop_index(op.f("ix_knowledge_chunks_category"), table_name="knowledge_chunks")
    op.drop_table("knowledge_chunks")
    # Do not DROP EXTENSION vector — other tables may depend on it later

"""add program_id to sessions

Revision ID: a3b8c9d1e2f4
Revises: fc245e195b5c
Create Date: 2026-07-21 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "a3b8c9d1e2f4"
down_revision: Union[str, Sequence[str], None] = "fc245e195b5c"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("sessions", sa.Column("program_id", sa.UUID(), nullable=True))
    op.create_index(
        op.f("ix_sessions_program_id"), "sessions", ["program_id"], unique=False
    )
    op.create_foreign_key(
        "fk_sessions_program_id_programs",
        "sessions",
        "programs",
        ["program_id"],
        ["id"],
    )


def downgrade() -> None:
    op.drop_constraint("fk_sessions_program_id_programs", "sessions", type_="foreignkey")
    op.drop_index(op.f("ix_sessions_program_id"), table_name="sessions")
    op.drop_column("sessions", "program_id")

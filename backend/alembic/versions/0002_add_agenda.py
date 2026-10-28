"""add agenda and ai_suggestion to meetings

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-28
"""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("meetings", sa.Column("agenda", JSONB(), nullable=True))
    op.add_column("meetings", sa.Column("ai_suggestion", JSONB(), nullable=True))


def downgrade() -> None:
    op.drop_column("meetings", "ai_suggestion")
    op.drop_column("meetings", "agenda")

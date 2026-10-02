"""create meetings table

Revision ID: 0001
Revises:
Create Date: 2026-09-29
"""
import sqlalchemy as sa
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "meetings",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("attendee_count", sa.Integer(), nullable=False),
        sa.CheckConstraint("ends_at > starts_at", name="ck_meetings_ends_after_starts"),
        sa.CheckConstraint("attendee_count >= 0", name="ck_meetings_attendee_count_nonneg"),
    )


def downgrade() -> None:
    op.drop_table("meetings")

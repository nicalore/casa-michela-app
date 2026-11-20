"""Calendar notes for teachers

Revision ID: f3a8c1d6b207
Revises: e5c2a8d4f106
Create Date: 2026-11-20
"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "f3a8c1d6b207"
down_revision = "e5c2a8d4f106"
branch_labels = None
depends_on = None

_NOTES: Final[str] = "calendar_teacher_notes"

_BAND_INDEX: Final[str] = "ix_calendar_teacher_note_band"

_AUTHOR_INDEX: Final[str] = f"ix_{_NOTES}_author_tax_code"


def upgrade() -> None:
    op.create_table(
        _NOTES,
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("band", sa.String(length=20), nullable=False),
        sa.Column("teacher_tax_code", sa.String(length=16), nullable=False),
        sa.Column("text", sa.String(length=1000), nullable=False),
        sa.Column("author_tax_code", sa.String(length=16), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            name=op.f(f"fk_{_NOTES}_teacher_tax_code_teachers"),
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["author_tax_code"],
            ["people.tax_code"],
            name=op.f(f"fk_{_NOTES}_author_tax_code_people"),
            onupdate="CASCADE",
            ondelete="SET NULL",
        ),
        sa.CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name=op.f(f"ck_{_NOTES}_calendar_teacher_note_band_valid"),
        ),
        sa.CheckConstraint(
            "length(trim(text)) > 0",
            name=op.f(f"ck_{_NOTES}_text_not_blank"),
        ),
        sa.CheckConstraint(
            "text IS NULL OR text = btrim(text)",
            name=op.f(f"ck_{_NOTES}_text_no_surrounding_whitespace"),
        ),
        sa.PrimaryKeyConstraint(
            "date",
            "band",
            "teacher_tax_code",
            name=op.f(f"pk_{_NOTES}"),
        ),
    )

    op.create_index(_BAND_INDEX, _NOTES, ["date", "band"])
    op.create_index(op.f(_AUTHOR_INDEX), _NOTES, ["author_tax_code"])


def downgrade() -> None:
    op.drop_index(op.f(_AUTHOR_INDEX), table_name=_NOTES)
    op.drop_index(_BAND_INDEX, table_name=_NOTES)
    op.drop_table(_NOTES)

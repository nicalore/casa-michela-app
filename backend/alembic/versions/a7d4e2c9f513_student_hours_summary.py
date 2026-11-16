"""The daily summary of pupils' hours; settled hours by day and band

Revision ID: a7d4e2c9f513
Revises: f3a9c5e17b24
Create Date: 2026-11-12
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "a7d4e2c9f513"
down_revision = "f3a9c5e17b24"
branch_labels = None
depends_on = None

_BANDS = "band IN ('MORNING', 'AFTERNOON', 'EVENING')"
_MODES = "mode IN ('presence', 'online')"


def _updated_at() -> sa.Column:
    return sa.Column(
        "updated_at",
        sa.DateTime(timezone=True),
        server_default=sa.text("now()"),
        nullable=False,
    )


def upgrade() -> None:
    op.create_table(
        "student_confirmed_bands",
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("band", sa.String(20), nullable=False),
        sa.Column(
            "confirmed_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("confirmed_by_tax_code", sa.String(16), nullable=True),
        sa.Column("reopened", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            _BANDS,
            name=op.f("ck_student_confirmed_bands_band_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["confirmed_by_tax_code"],
            ["people.tax_code"],
            name=op.f("fk_student_confirmed_bands_confirmed_by_tax_code_people"),
            ondelete="SET NULL",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "date",
            "band",
            name=op.f("pk_student_confirmed_bands"),
        ),
    )

    op.create_table(
        "student_confirmed_hours",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("student_tax_code", sa.String(16), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("band", sa.String(20), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=False),
        sa.Column("end_time", sa.Time(), nullable=False),
        sa.Column("mode", sa.String(20), nullable=False),
        sa.CheckConstraint(
            "end_time > start_time",
            name=op.f("ck_student_confirmed_hours_end_after_start"),
        ),
        sa.CheckConstraint(
            _MODES,
            name=op.f("ck_student_confirmed_hours_mode_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["student_tax_code"],
            ["students.tax_code"],
            name=op.f("fk_student_confirmed_hours_student_tax_code_students"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["date", "band"],
            ["student_confirmed_bands.date", "student_confirmed_bands.band"],
            name=op.f("fk_student_confirmed_hours_date_student_confirmed_bands"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_student_confirmed_hours")),
        sa.UniqueConstraint(
            "student_tax_code",
            "date",
            "start_time",
            name="unique_student_confirmed_hours",
        ),
    )
    op.create_index(
        op.f("ix_student_confirmed_hours_student_tax_code"),
        "student_confirmed_hours",
        ["student_tax_code"],
    )

    op.create_table(
        "student_hours_corrections",
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("band", sa.String(20), nullable=False),
        sa.Column("student_tax_code", sa.String(16), nullable=False),
        sa.Column("mode", sa.String(20), nullable=False),
        sa.Column("added", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("absent", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("work", postgresql.JSONB(), nullable=True),
        _updated_at(),
        sa.CheckConstraint(
            _BANDS,
            name=op.f("ck_student_hours_corrections_band_valid"),
        ),
        sa.CheckConstraint(
            _MODES,
            name=op.f("ck_student_hours_corrections_mode_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["student_tax_code"],
            ["students.tax_code"],
            name=op.f("fk_student_hours_corrections_student_tax_code_students"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "date",
            "band",
            "student_tax_code",
            name=op.f("pk_student_hours_corrections"),
        ),
    )

    op.create_table(
        "student_payment_bands",
        sa.Column("payment_id", sa.Integer(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("band", sa.String(20), nullable=False),
        sa.Column("minutes", sa.Integer(), nullable=False),
        sa.CheckConstraint(
            "minutes > 0",
            name=op.f("ck_student_payment_bands_minutes_positive"),
        ),
        sa.CheckConstraint(
            _BANDS,
            name=op.f("ck_student_payment_bands_band_valid"),
        ),
        sa.ForeignKeyConstraint(
            ["payment_id"],
            ["student_payments.id"],
            name=op.f("fk_student_payment_bands_payment_id_student_payments"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "payment_id",
            "date",
            "band",
            name=op.f("pk_student_payment_bands"),
        ),
    )

    # Hours already settled keep their minutes, now by the band of their lesson.
    op.execute(
        """
        INSERT INTO student_payment_bands (payment_id, date, band, minutes)
        SELECT links.payment_id, lessons.date, lessons.band, SUM(links.minutes)
        FROM student_payment_lessons AS links
        JOIN lessons ON lessons.id = links.lesson_id
        GROUP BY links.payment_id, lessons.date, lessons.band
        """
    )

    op.drop_table("student_payment_lessons")


# The lessons a band's minutes came from are not known any more: the minutes
# settled go with the downgrade, the payments stay.
def downgrade() -> None:
    op.create_table(
        "student_payment_lessons",
        sa.Column("payment_id", sa.Integer(), nullable=False),
        sa.Column("lesson_id", sa.Integer(), nullable=False),
        sa.Column("minutes", sa.Integer(), nullable=False),
        sa.CheckConstraint(
            "minutes > 0",
            name=op.f("ck_student_payment_lessons_minutes_positive"),
        ),
        sa.ForeignKeyConstraint(
            ["payment_id"],
            ["student_payments.id"],
            name=op.f("fk_student_payment_lessons_payment_id_student_payments"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["lesson_id"],
            ["lessons.id"],
            name=op.f("fk_student_payment_lessons_lesson_id_lessons"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "payment_id",
            "lesson_id",
            name=op.f("pk_student_payment_lessons"),
        ),
    )
    op.create_index(
        op.f("ix_student_payment_lessons_lesson_id"),
        "student_payment_lessons",
        ["lesson_id"],
    )

    op.drop_table("student_payment_bands")
    op.drop_table("student_hours_corrections")
    op.drop_index(
        op.f("ix_student_confirmed_hours_student_tax_code"),
        table_name="student_confirmed_hours",
    )
    op.drop_table("student_confirmed_hours")
    op.drop_table("student_confirmed_bands")

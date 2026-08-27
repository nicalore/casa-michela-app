"""add hand-written calendar activities

Revision ID: a3d59f21c4b7
Revises: d7c4b91e08a3
Create Date: 2026-08-26

"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "a3d59f21c4b7"
down_revision = "d7c4b91e08a3"
branch_labels = None
depends_on = None

_ACTIVITIES: Final[str] = "calendar_activities"

_BAND_LENGTH: Final[int] = 20
_MODE_LENGTH: Final[int] = 20
_NAME_LENGTH: Final[int] = 255
_DESCRIPTION_LENGTH: Final[int] = 1000

_AVAILABILITY_INDEX: Final[str] = "ix_calendar_activities_availability_id"

_DAY_INDEX: Final[str] = "ix_calendar_activity_day"

_AVAILABILITY_FK: Final[str] = "calendar_activities_availability_fkey"

# Written exactly as app/models/calendar_activity.py renders them.
_ASSIGNMENT: Final[tuple[str, ...]] = (
    "availability_id",
    "teacher_mode",
    "start_time",
    "end_time",
)

_UNASSIGNED: Final[str] = " AND ".join(f"{column} IS NULL" for column in _ASSIGNMENT)

_ASSIGNED: Final[str] = " AND ".join(f"{column} IS NOT NULL" for column in _ASSIGNMENT)

_WITHIN_BAND: Final[str] = (
    "start_time IS NULL "
    "OR (band = 'MORNING' AND start_time >= TIME '06:00' "
    "AND end_time <= TIME '13:00') "
    "OR (band = 'AFTERNOON' AND start_time >= TIME '13:00' "
    "AND end_time <= TIME '19:00') "
    "OR (band = 'EVENING' AND start_time >= TIME '19:00' "
    "AND end_time <= TIME '23:00')"
)


def upgrade() -> None:
    op.create_table(
        _ACTIVITIES,
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("band", sa.String(length=_BAND_LENGTH), nullable=False),
        sa.Column("name", sa.String(length=_NAME_LENGTH), nullable=False),
        sa.Column(
            "description",
            sa.String(length=_DESCRIPTION_LENGTH),
            nullable=True,
        ),
        sa.Column("availability_id", sa.Integer(), nullable=True),
        sa.Column("teacher_mode", sa.String(length=_MODE_LENGTH), nullable=True),
        sa.Column("start_time", sa.Time(), nullable=True),
        sa.Column("end_time", sa.Time(), nullable=True),
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
        sa.CheckConstraint(
            "id > 0",
            name=op.f("ck_calendar_activities_positive_calendar_activity_id"),
        ),
        sa.CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name=op.f("ck_calendar_activities_calendar_activity_band_valid"),
        ),
        sa.CheckConstraint(
            "teacher_mode IS NULL OR teacher_mode IN ('presence', 'online')",
            name=op.f("ck_calendar_activities_calendar_activity_teacher_mode_valid"),
        ),
        sa.CheckConstraint(
            f"({_UNASSIGNED}) OR ({_ASSIGNED})",
            name=op.f("ck_calendar_activities_calendar_activity_assignment_whole"),
        ),
        sa.CheckConstraint(
            "end_time > start_time",
            name=op.f("ck_calendar_activities_calendar_activity_end_after_start"),
        ),
        sa.CheckConstraint(
            "start_time IS NULL "
            "OR (EXTRACT(MINUTE FROM start_time)::integer % 15 = 0 "
            "AND EXTRACT(MINUTE FROM end_time)::integer % 15 = 0)",
            name=op.f("ck_calendar_activities_calendar_activity_time_step"),
        ),
        sa.CheckConstraint(
            _WITHIN_BAND,
            name=op.f("ck_calendar_activities_calendar_activity_within_band"),
        ),
        sa.CheckConstraint(
            "length(trim(name)) > 0",
            name=op.f("ck_calendar_activities_name_not_blank"),
        ),
        sa.CheckConstraint(
            "description IS NULL OR length(trim(description)) > 0",
            name=op.f("ck_calendar_activities_description_not_blank"),
        ),
        sa.CheckConstraint(
            "name IS NULL OR name = btrim(name)",
            name=op.f("ck_calendar_activities_name_no_surrounding_whitespace"),
        ),
        sa.CheckConstraint(
            "description IS NULL OR description = btrim(description)",
            name=op.f(
                "ck_calendar_activities_description_no_surrounding_whitespace",
            ),
        ),
        # RESTRICT: an availability carrying an activity cannot be deleted or
        # moved; the service removes the assignment first, so the DB never refuses.
        sa.ForeignKeyConstraint(
            ["availability_id", "date", "teacher_mode"],
            [
                "availabilities.id",
                "availabilities.date",
                "availabilities.mode",
            ],
            name=op.f(_AVAILABILITY_FK),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_calendar_activities")),
    )
    op.create_index(
        op.f(_AVAILABILITY_INDEX),
        _ACTIVITIES,
        ["availability_id"],
        unique=False,
    )
    op.create_index(_DAY_INDEX, _ACTIVITIES, ["date", "band"], unique=False)


def downgrade() -> None:
    op.drop_index(_DAY_INDEX, table_name=_ACTIVITIES)
    op.drop_index(op.f(_AVAILABILITY_INDEX), table_name=_ACTIVITIES)
    op.drop_table(_ACTIVITIES)

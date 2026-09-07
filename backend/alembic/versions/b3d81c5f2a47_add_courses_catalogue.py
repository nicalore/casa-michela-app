"""add courses catalogue

Revision ID: b3d81c5f2a47
Revises: e4b7c02a91f5
Create Date: 2026-09-07
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "b3d81c5f2a47"
down_revision = "e4b7c02a91f5"
branch_labels = None
depends_on = None


course_type_enum = postgresql.ENUM(
    "YOGA", "PILATES",
    name="course_type_enum",
)

# The enum members the catalogue starts from, paired with the name that
# replaces them once courses become rows.
_SEEDED_COURSES: tuple[tuple[str, str], ...] = (
    ("YOGA", "Yoga"),
    ("PILATES", "Pilates"),
)


def upgrade() -> None:
    op.create_table(
        "courses",
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("description", sa.String(length=1000), nullable=True),
        sa.Column("cost", sa.String(length=100), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "length(trim(name)) > 0",
            name=op.f("ck_courses_name_not_blank"),
        ),
        sa.CheckConstraint(
            "name IS NULL OR name = btrim(name)",
            name=op.f("ck_courses_name_no_surrounding_whitespace"),
        ),
        sa.CheckConstraint(
            "description IS NULL OR length(trim(description)) > 0",
            name=op.f("ck_courses_description_not_blank"),
        ),
        sa.CheckConstraint(
            "description IS NULL OR description = btrim(description)",
            name=op.f("ck_courses_description_no_surrounding_whitespace"),
        ),
        sa.CheckConstraint(
            "cost IS NULL OR length(trim(cost)) > 0",
            name=op.f("ck_courses_cost_not_blank"),
        ),
        sa.CheckConstraint(
            "cost IS NULL OR cost = btrim(cost)",
            name=op.f("ck_courses_cost_no_surrounding_whitespace"),
        ),
        sa.PrimaryKeyConstraint("name", name=op.f("pk_courses")),
    )

    # The two enum members become the first rows of the catalogue, so the
    # foreign key below has something to point at.
    for _, name in _SEEDED_COURSES:
        op.execute(f"INSERT INTO courses (name) VALUES ('{name}')")

    op.alter_column(
        "course_participants",
        "course_type",
        existing_type=course_type_enum,
        type_=sa.String(length=255),
        existing_nullable=False,
        postgresql_using="course_type::VARCHAR(255)",
    )

    for member, name in _SEEDED_COURSES:
        op.execute(
            "UPDATE course_participants "
            f"SET course_type = '{name}' "
            f"WHERE course_type = '{member}'"
        )

    op.create_foreign_key(
        op.f("fk_course_participants_course_type_courses"),
        "course_participants",
        "courses",
        ["course_type"],
        ["name"],
        onupdate="CASCADE",
        ondelete="RESTRICT",
    )

    course_type_enum.drop(op.get_bind(), checkfirst=True)


def downgrade() -> None:
    course_type_enum.create(op.get_bind(), checkfirst=True)

    op.drop_constraint(
        op.f("fk_course_participants_course_type_courses"),
        "course_participants",
        type_="foreignkey",
    )

    # Courses added after the upgrade have no enum member: their participants
    # fall back to the first seeded course rather than blocking the downgrade.
    fallback = _SEEDED_COURSES[0][1]
    known = ", ".join(f"'{name}'" for _, name in _SEEDED_COURSES)

    op.execute(
        "UPDATE course_participants "
        f"SET course_type = '{fallback}' "
        f"WHERE course_type NOT IN ({known})"
    )

    op.alter_column(
        "course_participants",
        "course_type",
        existing_type=sa.String(length=255),
        type_=course_type_enum,
        existing_nullable=False,
        postgresql_using="UPPER(course_type)::course_type_enum",
    )

    op.drop_table("courses")

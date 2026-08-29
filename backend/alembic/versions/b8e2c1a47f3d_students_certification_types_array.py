"""Let a pupil hold more than one certification

Revision ID: b8e2c1a47f3d
Revises: e7b04c9d15a2
Create Date: 2026-08-28 22:10:00.000000

"""

from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "b8e2c1a47f3d"
down_revision: str | None = "e7b04c9d15a2"
branch_labels: str | None = None
depends_on: str | None = None

_ENUM = postgresql.ENUM(
    "DSA",
    "BES",
    "ADHD",
    "OTHER",
    name="certification_type_enum",
    create_type=False,
)

_OLD_CHECKS = (
    "certification_other_detail_requires_other_type",
    "dsa_certification_says_which",
    "certification_dsa_detail_requires_dsa_type",
)


def upgrade() -> None:
    for name in _OLD_CHECKS:
        op.drop_constraint(name, "students", type_="check")

    op.alter_column(
        "students",
        "certification_type",
        new_column_name="certification_types",
        type_=postgresql.ARRAY(_ENUM),
        postgresql_using=(
            "CASE WHEN certification_type IS NULL "
            "THEN '{}'::certification_type_enum[] "
            "ELSE ARRAY[certification_type] END"
        ),
        nullable=False,
        server_default="{}",
    )

    op.create_check_constraint(
        "certification_other_detail_requires_other_type",
        "students",
        "certification_other_detail IS NULL OR 'OTHER' = ANY(certification_types)",
    )
    op.create_check_constraint(
        "dsa_certification_says_which",
        "students",
        "NOT ('DSA' = ANY(certification_types)) OR certification_dsa_detail IS NOT NULL",
    )
    op.create_check_constraint(
        "certification_dsa_detail_requires_dsa_type",
        "students",
        "certification_dsa_detail IS NULL OR 'DSA' = ANY(certification_types)",
    )


def downgrade() -> None:
    for name in _OLD_CHECKS:
        op.drop_constraint(name, "students", type_="check")

    # Must precede the type change: the empty-set default cannot cast to the scalar type.
    op.execute("ALTER TABLE students ALTER COLUMN certification_types DROP DEFAULT")

    # Lossy: the scalar column keeps only the first certification.
    op.alter_column(
        "students",
        "certification_types",
        new_column_name="certification_type",
        type_=_ENUM,
        postgresql_using=(
            "CASE WHEN cardinality(certification_types) = 0 "
            "THEN NULL ELSE certification_types[1] END"
        ),
        nullable=True,
        server_default=None,
    )

    op.create_check_constraint(
        "certification_other_detail_requires_other_type",
        "students",
        "certification_other_detail IS NULL "
        "OR certification_type IS NOT DISTINCT FROM 'OTHER'",
    )
    op.create_check_constraint(
        "dsa_certification_says_which",
        "students",
        "certification_type IS DISTINCT FROM 'DSA' "
        "OR certification_dsa_detail IS NOT NULL",
    )
    op.create_check_constraint(
        "certification_dsa_detail_requires_dsa_type",
        "students",
        "certification_dsa_detail IS NULL "
        "OR certification_type IS NOT DISTINCT FROM 'DSA'",
    )

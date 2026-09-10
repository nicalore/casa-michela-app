"""Record the Aiuto Compiti rate a pupil chose

Revision ID: a91c4d7e0f38
Revises: d4e8b1c73a56
Create Date: 2026-09-10
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "a91c4d7e0f38"
down_revision = "d4e8b1c73a56"
branch_labels = None
depends_on = None

_TARIFF_VALUES = (
    "PRIMARY_MONTHLY",
    "MIDDLE_HOURLY",
    "MIDDLE_PACKAGE",
    "HIGH_HOURLY",
    "HIGH_PACKAGE",
)


def upgrade() -> None:
    # The type has to exist before the column can name it.
    tariff_enum = postgresql.ENUM(*_TARIFF_VALUES, name="homework_tariff_enum")
    tariff_enum.create(op.get_bind(), checkfirst=True)

    # Nullable with no backfill: nobody on file was ever asked.
    op.add_column(
        "students",
        sa.Column("homework_tariff", tariff_enum, nullable=True),
    )


def downgrade() -> None:
    op.drop_column("students", "homework_tariff")

    postgresql.ENUM(name="homework_tariff_enum").drop(op.get_bind(), checkfirst=True)

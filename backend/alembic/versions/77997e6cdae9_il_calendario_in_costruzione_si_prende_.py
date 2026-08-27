"""heartbeat locks so a calendar band is built by one administrator at a time

Revision ID: 77997e6cdae9
Revises: b8d3e5f21a47
Create Date: 2026-08-25 22:52:38.251888

"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "77997e6cdae9"
down_revision = "b8d3e5f21a47"
branch_labels = None
depends_on = None

_LOCKS: Final[str] = "calendar_band_locks"
_PUBLICATIONS: Final[str] = "calendar_publications"

_HOLDER: Final[str] = "holder_tax_code"
_DRAFT_OPENED_BY: Final[str] = "draft_opened_by"

_TAX_CODE_LENGTH: Final[int] = 16
_BAND_LENGTH: Final[int] = 20

_HOLDER_INDEX: Final[str] = "ix_calendar_band_locks_holder_tax_code"

_HOLDER_FK: Final[str] = "fk_calendar_band_locks_holder_tax_code_administrators"

_DRAFT_FK: Final[str] = (
    "fk_calendar_publications_draft_opened_by_administrators"
)


def upgrade() -> None:
    op.create_table(
        _LOCKS,
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("band", sa.String(length=_BAND_LENGTH), nullable=False),
        sa.Column(_HOLDER, sa.String(length=_TAX_CODE_LENGTH), nullable=False),
        # When the band was taken; heartbeats update heartbeat_at, never this.
        sa.Column(
            "acquired_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "heartbeat_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name=op.f("ck_calendar_band_locks_calendar_band_lock_band_valid"),
        ),
        # CASCADE: a lock held by a deleted administrator would never be freed.
        sa.ForeignKeyConstraint(
            [_HOLDER],
            ["administrators.tax_code"],
            name=op.f(_HOLDER_FK),
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("date", "band", name=op.f("pk_calendar_band_locks")),
    )
    op.create_index(op.f(_HOLDER_INDEX), _LOCKS, [_HOLDER], unique=False)

    # Drafts already open at migration time keep a NULL author and can still be
    # exited — same convention as a missing expected_updated_at.
    op.add_column(
        _PUBLICATIONS,
        sa.Column(_DRAFT_OPENED_BY, sa.String(length=_TAX_CODE_LENGTH), nullable=True),
    )
    op.create_foreign_key(
        op.f(_DRAFT_FK),
        _PUBLICATIONS,
        "administrators",
        [_DRAFT_OPENED_BY],
        ["tax_code"],
        onupdate="CASCADE",
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(op.f(_DRAFT_FK), _PUBLICATIONS, type_="foreignkey")
    op.drop_column(_PUBLICATIONS, _DRAFT_OPENED_BY)
    op.drop_index(op.f(_HOLDER_INDEX), table_name=_LOCKS)
    op.drop_table(_LOCKS)

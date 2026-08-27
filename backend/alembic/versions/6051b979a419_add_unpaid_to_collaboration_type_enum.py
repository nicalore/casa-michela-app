"""Add unpaid to collaboration type enum

Revision ID: 6051b979a419
Revises: 9f64b3d8f455
Create Date: 2026-07-17

"""
from alembic import op

# revision identifiers, used by Alembic.
revision = "6051b979a419"
down_revision = "9f64b3d8f455"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ALTER TYPE ... ADD VALUE cannot run in Alembic's default transaction:
    # Postgres forbids using a new enum value in the transaction that adds it.
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE collaboration_type_enum ADD VALUE 'UNPAID'")


def downgrade() -> None:
    # Postgres has no DROP VALUE for native enums; a clean downgrade would need
    # to recreate the type and handle rows already using UNPAID. Not handled.
    raise NotImplementedError(
        "Downgrade non supportato: Postgres non permette di rimuovere "
        "un valore da un enum nativo."
    )
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
    # ALTER TYPE ... ADD VALUE non può girare nella transazione di default
    # di Alembic (Postgres non permette di usare un nuovo valore enum
    # nella stessa transazione in cui viene aggiunto). Lo eseguiamo quindi
    # in un blocco autocommit dedicato.
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE collaboration_type_enum ADD VALUE 'UNPAID'")


def downgrade() -> None:
    # Postgres non supporta DROP VALUE su un enum nativo: un downgrade
    # pulito richiederebbe ricreare il tipo da zero e gestire eventuali
    # righe che nel frattempo avessero usato UNPAID. Non gestito.
    raise NotImplementedError(
        "Downgrade non supportato: Postgres non permette di rimuovere "
        "un valore da un enum nativo."
    )

"""schools: allarga mechanographic_code da 20 a 100 caratteri

Revision ID: 0d17f8e553a3
Revises: aa410838d808

"""
from alembic import op
import sqlalchemy as sa

revision = "0d17f8e553a3"
down_revision = "aa410838d808"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Ampliamento del limite: alcuni istituti hanno più di un codice ufficiale
    # (es. plessi/sedi con livelli scolastici diversi). ALTER COLUMN TYPE che
    # allarga un varchar è un'operazione solo di metadati in Postgres,
    # non riscrive la tabella.
    op.alter_column(
        "schools", "mechanographic_code",
        existing_type=sa.String(20),
        type_=sa.String(100),
        existing_nullable=True,
    )


def downgrade() -> None:
    # Il downgrade fallisce se sono presenti codici più lunghi di 20
    # caratteri (comportamento atteso: non è possibile ridurre il limite
    # perdendo dati senza troncarli esplicitamente).
    op.alter_column(
        "schools", "mechanographic_code",
        existing_type=sa.String(100),
        type_=sa.String(20),
        existing_nullable=True,
    )
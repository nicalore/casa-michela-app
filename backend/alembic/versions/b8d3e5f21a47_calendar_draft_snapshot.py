"""la bozza conserva com'era la giornata, non solo la sua impronta

Uscire da una bozza senza pubblicare adesso annulla davvero il lavoro fatto
dentro: la parte di giornata torna com'era quando la bozza si è aperta. Un'
impronta sapeva solo dire se qualcosa era cambiato, e per rimettere le cose a
posto servono le righe.

La colonna tiene la fotografia: le lezioni con le loro discipline e prenotazioni,
e le stanze e i turni. Non nulla significa "in bozza", come prima significava
l'impronta.

Revision ID: b8d3e5f21a47
Revises: a4f7c2e91b30
Create Date: 2026-08-23 00:00:00.000000

"""

from typing import Final

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision = "b8d3e5f21a47"
down_revision = "a4f7c2e91b30"
branch_labels = None
depends_on = None

_TABLE: Final[str] = "calendar_publications"
_OLD: Final[str] = "draft_fingerprint"
_NEW: Final[str] = "draft_snapshot"


def upgrade() -> None:
    op.add_column(
        _TABLE,
        sa.Column(_NEW, postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )
    # Le bozze aperte al momento del passaggio non hanno una fotografia da cui
    # ripartire. Si chiudono: quello che c'è dentro resta scritto, e chi le
    # aveva aperte le riapre.
    op.drop_column(_TABLE, _OLD)


def downgrade() -> None:
    op.add_column(_TABLE, sa.Column(_OLD, sa.String(length=64), nullable=True))
    op.drop_column(_TABLE, _NEW)

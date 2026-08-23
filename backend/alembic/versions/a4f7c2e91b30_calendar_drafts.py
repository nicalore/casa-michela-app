"""il calendario pubblicato si riapre in bozza

Riportare una fascia in bozza non la toglie più dalle mani di chi la sta
guardando: docenti, genitori e studenti continuano a vedere il calendario
pubblicato mentre l'amministrazione lo rilavora. Quello che cambia è se, alla
chiusura della bozza, il calendario viene mandato di nuovo.

Serve quindi ricordare com'era la fascia quando la bozza si è aperta, e la
colonna tiene esattamente quello: l'impronta del suo contenuto pubblico.
Non nulla significa "in bozza", com'è la riga stessa a significare
"pubblicato"; e all'uscita basta ricalcolare l'impronta e confrontarla per
sapere se qualcosa è davvero cambiato — una lezione spostata e rimessa dov'era
non è una modifica.

Revision ID: a4f7c2e91b30
Revises: 80eaead2769d
Create Date: 2026-08-20 00:00:00.000000

"""

from typing import Final

import sqlalchemy as sa

from alembic import op

revision = "a4f7c2e91b30"
down_revision = "80eaead2769d"
branch_labels = None
depends_on = None

_TABLE: Final[str] = "calendar_publications"
_COLUMN: Final[str] = "draft_fingerprint"

_LENGTH: Final[int] = 64


def upgrade() -> None:
    op.add_column(
        _TABLE,
        sa.Column(_COLUMN, sa.String(length=_LENGTH), nullable=True),
    )


def downgrade() -> None:
    op.drop_column(_TABLE, _COLUMN)

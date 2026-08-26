"""il calendario in costruzione si prende in carico

Costruire il calendario di una fascia è il lavoro di una persona per una mezz'
ora, e finora niente impediva a due amministratori di farlo insieme senza
saperlo. La riga dice chi la sta costruendo adesso.

Si prende scrivendo — entrare a guardare non prende niente — e la si tiene
finché arrivano battiti: heartbeat_at è l'ultimo segno di vita, e un lock più
vecchio di novanta secondi è libero per chiunque lo legga dopo. Non c'è niente
da spazzare e niente che possa non partire, perché l'età si legge insieme alla
riga.

Tabella a parte e non una colonna su calendar_publications: lì una riga che
esiste *significa* pubblicato, e una fascia ha bisogno di un titolare proprio
mentre non è mai stata pubblicata.

La seconda colonna è per la bozza, che il lock non arriva a coprire: la bozza
resta aperta per giorni e il lock dura un minuto e mezzo. Uscirne senza
pubblicare rimette la fascia com'era quando si è aperta, quindi chi non l'ha
aperta annullerebbe anche il proprio lavoro senza poterlo sapere.

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
        # Quando la fascia è stata presa, che è quello che il banner dice ad
        # alta voce. Il battito muove heartbeat_at e lascia stare questa.
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
        # Se l'amministratore non c'è più, non c'è più nemmeno il lock: una
        # fascia trattenuta da nessuno non si libererebbe mai.
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

    # Le bozze già aperte al momento del passaggio restano senza autore, e chi
    # le trova può uscirne: è la stessa convenzione dell'expected_updated_at
    # assente, dove quello che è nato prima della regola continua a passare.
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

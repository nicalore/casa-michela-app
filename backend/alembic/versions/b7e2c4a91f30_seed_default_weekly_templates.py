"""seed default weekly templates

Revision ID: b7e2c4a91f30
Revises: 8c53d40f2cfd
Create Date: 2026-07-26

"""

from alembic import op

revision = "b7e2c4a91f30"
down_revision = "8c53d40f2cfd"
branch_labels = None
depends_on = None

_DEFAULT_START = "14:00"
_DEFAULT_END = "18:30"
_DEFAULT_WEEKDAYS = (1, 2, 3, 4, 5)


def upgrade() -> None:
    # Orario standard di partenza, in presenza e online.
    #
    # Riempie i buchi per singolo (giorno, modalità), non solo su una tabella
    # del tutto vuota: un'associazione che ha già configurato la presenza ma
    # non l'online resterebbe altrimenti senza alcun default sull'online. Le
    # combinazioni già configurate non vengono toccate.
    #
    # I letterali in VALUES arrivano come text: senza cast espliciti Postgres
    # non li accetta per le colonne smallint/time.
    values = ", ".join(
        f"({weekday}::smallint, '{mode}', "
        f"'{_DEFAULT_START}'::time, '{_DEFAULT_END}'::time)"
        for weekday in _DEFAULT_WEEKDAYS
        for mode in ("presence", "online")
    )

    op.execute(
        f"""
        INSERT INTO weekly_templates (weekday, mode, start_time, end_time)
        SELECT d.weekday, d.mode, d.start_time, d.end_time
        FROM (VALUES {values}) AS d(weekday, mode, start_time, end_time)
        WHERE NOT EXISTS (
            SELECT 1 FROM weekly_templates existing
            WHERE existing.weekday = d.weekday AND existing.mode = d.mode
        )
        """
    )


def downgrade() -> None:
    # Rimuove solo le righe identiche al default, così un orario modificato
    # dall'amministratore non viene toccato.
    weekdays = ", ".join(str(weekday) for weekday in _DEFAULT_WEEKDAYS)

    op.execute(
        f"""
        DELETE FROM weekly_templates
        WHERE weekday IN ({weekdays})
          AND mode IN ('presence', 'online')
          AND start_time = '{_DEFAULT_START}'
          AND end_time = '{_DEFAULT_END}'
        """
    )

"""add sector to study_programs

Revision ID: d3f7a2b81c45
Revises: c4d81a55e903
Create Date: 2026-07-31
"""

import sqlalchemy as sa

from alembic import op

revision = "d3f7a2b81c45"
down_revision = "c4d81a55e903"
branch_labels = None
depends_on = None

_SEPARATOR = "|"


def upgrade() -> None:
    op.add_column("study_programs", sa.Column("sector", sa.String(length=100), nullable=True))

    # Prima il settore, poi il nome accorciato: l'ordine conta, perché il secondo
    # UPDATE cancella la sorgente da cui legge il primo.
    op.execute(
        f"""
        UPDATE study_programs
        SET sector = btrim(split_part(name, '{_SEPARATOR}', 1))
        WHERE position('{_SEPARATOR}' in name) > 0
          AND btrim(split_part(name, '{_SEPARATOR}', 1)) <> ''
        """
    )

    op.create_check_constraint(
        "study_program_sector_not_blank",
        "study_programs",
        "sector IS NULL OR length(trim(sector)) > 0",
    )
    op.create_check_constraint(
        "sector_no_surrounding_whitespace",
        "study_programs",
        "sector IS NULL OR sector = btrim(sector)",
    )

    # I vincoli vanno scambiati PRIMA di accorciare i nomi: senza il settore
    # dentro name, (level, name) non è più una chiave.
    op.drop_constraint("uq_level_program_name", "study_programs", type_="unique")
    op.execute(
        "CREATE UNIQUE INDEX uq_level_sector_program_name "
        "ON study_programs (level, coalesce(sector, ''), name)"
    )

    # Solo dove lo spoglio lascia davvero un nome: una riga chiamata
    # "Liceo classico |" resterebbe senza nome, e il vincolo di non vuoto la
    # rifiuterebbe.
    op.execute(
        f"""
        UPDATE study_programs
        SET name = btrim(split_part(name, '{_SEPARATOR}', 2))
        WHERE sector IS NOT NULL
          AND btrim(split_part(name, '{_SEPARATOR}', 2)) <> ''
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_level_sector_program_name")

    # Il nome torna a portarsi dentro il settore, così la riga resta riconoscibile
    # e il vincolo di prima può reggere di nuovo.
    op.execute(
        f"""
        UPDATE study_programs
        SET name = sector || ' {_SEPARATOR} ' || name
        WHERE sector IS NOT NULL
        """
    )

    op.create_unique_constraint(
        "uq_level_program_name",
        "study_programs",
        ["level", "name"],
    )

    op.drop_constraint(
        "sector_no_surrounding_whitespace",
        "study_programs",
        type_="check",
    )
    op.drop_constraint("study_program_sector_not_blank", "study_programs", type_="check")
    op.drop_column("study_programs", "sector")
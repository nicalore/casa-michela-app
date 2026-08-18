"""consenti lezioni sovrapposte per un docente

Toglie l'indice unico su (availability_id, start_time).

Era una guardia contro il doppio clic, sulla lettura che due lezioni della
stessa disponibilità che cominciano nello stesso minuto potessero solo essere
una lezione inserita due volte. Quella lettura non vale più: un docente che
prende due alunni dalle due, uno per ciascuno, sono due righe con la stessa
disponibilità e lo stesso inizio, ed è esattamente ciò che il calendario deve
permettere.

Nessuna chiave naturale distingue quel caso da un doppio clic, quindi la
guardia sparisce invece di restare sbagliata. Ciò che limita la giornata di un
docente è il numero di alunni in contemporanea, verificato in
app/services/teacher_occupancy.py.

Revision ID: 80eaead2769d
Revises: 8369059fdad9
Create Date: 2026-08-10 00:00:00.000000

"""

from typing import Final

from alembic import op

# revision identifiers, used by Alembic.
revision = "80eaead2769d"
down_revision = "8369059fdad9"
branch_labels = None
depends_on = None

_TABLE: Final[str] = "lessons"
_INDEX: Final[str] = "ux_lesson_slot"
_COLUMNS: Final[list[str]] = ["availability_id", "start_time"]


def upgrade() -> None:
    # Nome esplicito: op.f() cercherebbe un indice mai esistito con quel nome.
    op.drop_index(_INDEX, table_name=_TABLE)


def downgrade() -> None:
    # Può fallire su un database che intanto tiene lezioni sovrapposte: è il
    # prezzo di tornare indietro su un vincolo allentato.
    op.create_index(_INDEX, _TABLE, _COLUMNS, unique=True)

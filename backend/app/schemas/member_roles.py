from typing import Literal

# What accounting lists filter people by.
MemberRole = Literal[
    "STUDENTE",
    "DOCENTE",
    "CORSISTA",
    "GENITORE",
    "AMMINISTRATORE",
    "PSICOLOGO",
]

from pathlib import Path
from typing import Final

UPLOADS_DIR: Final[Path] = Path("uploads")

PROFILE_IMAGES_DIR: Final[Path] = UPLOADS_DIR / "profile-images"

# Must match the StaticFiles mount of UPLOADS_DIR, so both derive from the same path.
PROFILE_IMAGES_URL_PREFIX: Final[str] = f"/{PROFILE_IMAGES_DIR.as_posix()}"

# Resolved from the package, not the working directory: pytest, uvicorn and scripts
# each run from somewhere else.
DOCUMENTS_DIR: Final[Path] = Path(__file__).resolve().parents[1] / "documents"

ENROLLMENT_FORM_TEMPLATE: Final[Path] = (
    DOCUMENTS_DIR / "modulo_iscrizione_26-27_v2_acroform.pdf"
)

ENROLLMENT_FORM_FIELD_MAP: Final[Path] = DOCUMENTS_DIR / "mappa_campi_modulo_v2.json"

EARLY_EXIT_FORM_TEMPLATE: Final[Path] = (
    DOCUMENTS_DIR / "modulo_uscita_anticipata_acroform.pdf"
)

EARLY_EXIT_FORM_FIELD_MAP: Final[Path] = DOCUMENTS_DIR / "mappa_campi_uscita.json"

# Embedded into the filled forms; OFL.txt beside it is the licence it ships under.
ENROLLMENT_FORM_FONT: Final[Path] = DOCUMENTS_DIR / "PlusJakartaSans-Regular.ttf"

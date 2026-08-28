from pathlib import Path
from typing import Final

UPLOADS_DIR: Final[Path] = Path("uploads")

PROFILE_IMAGES_DIR: Final[Path] = UPLOADS_DIR / "profile-images"

# Public prefix of the images: it has to match the StaticFiles mount of
# UPLOADS_DIR, so both are derived from the same path.
PROFILE_IMAGES_URL_PREFIX: Final[str] = f"/{PROFILE_IMAGES_DIR.as_posix()}"

# Read-only assets shipped with the code. Resolved from the package and not
# from the working directory as UPLOADS_DIR is: that form only holds for a
# directory the server itself creates and serves, while pytest, uvicorn and a
# script each run from somewhere else.
DOCUMENTS_DIR: Final[Path] = Path(__file__).resolve().parents[1] / "documents"

ENROLLMENT_FORM_TEMPLATE: Final[Path] = DOCUMENTS_DIR / "modulo_iscrizione_26-27.pdf"

ENROLLMENT_FORM_FIELD_MAP: Final[Path] = DOCUMENTS_DIR / "mappa_campi_modulo.json"

# The app's own typeface, embedded in the filled form so what the office prints
# reads like what it typed. OFL.txt beside it is the licence it ships under.
ENROLLMENT_FORM_FONT: Final[Path] = DOCUMENTS_DIR / "PlusJakartaSans-Regular.ttf"

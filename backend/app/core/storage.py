import re
import secrets
from io import BytesIO
from pathlib import Path
from typing import Final

from PIL import Image, ImageOps, UnidentifiedImageError

UPLOADS_DIR: Final[Path] = Path("uploads")

PROFILE_IMAGES_DIR: Final[Path] = UPLOADS_DIR / "profile-images"

# The prefix of the route that serves them, stored with each name.
PROFILE_IMAGES_URL_PREFIX: Final[str] = "/profile-images"

_PROFILE_IMAGE_NAME: Final[re.Pattern[str]] = re.compile(r"[0-9a-f]{32}\.jpg")

# Avatars are drawn small: a phone photo shrinks to this before it is kept.
PROFILE_IMAGE_MAX_SIDE: Final[int] = 512
PROFILE_IMAGE_QUALITY: Final[int] = 85

INVALID_IMAGE_ERROR: Final[str] = "Sono ammesse solo immagini JPEG, PNG e WEBP"


# A random name per upload: the URL says nothing of its owner and moves with the photo.
def store_profile_image(previous_url: str | None, content: bytes) -> str:
    try:
        with Image.open(BytesIO(content)) as image:
            oriented = ImageOps.exif_transpose(image).convert("RGBA")

    except UnidentifiedImageError:
        raise ValueError(INVALID_IMAGE_ERROR) from None

    flattened = Image.new("RGB", oriented.size, "white")
    flattened.paste(oriented, mask=oriented.getchannel("A"))
    flattened.thumbnail((PROFILE_IMAGE_MAX_SIDE, PROFILE_IMAGE_MAX_SIDE))

    PROFILE_IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    discard_profile_image(previous_url)

    filename = f"{secrets.token_hex(16)}.jpg"
    flattened.save(
        PROFILE_IMAGES_DIR / filename,
        format="JPEG",
        quality=PROFILE_IMAGE_QUALITY,
        optimize=True,
    )

    return f"{PROFILE_IMAGES_URL_PREFIX}/{filename}"


def discard_profile_image(url: str | None) -> None:
    if url is not None:
        (PROFILE_IMAGES_DIR / Path(url).name).unlink(missing_ok=True)


# None for a name this module never gives out, so no path leaves the folder.
def profile_image_file(name: str) -> Path | None:
    if _PROFILE_IMAGE_NAME.fullmatch(name) is None:
        return None

    return PROFILE_IMAGES_DIR / name


# Resolved from the package, not the working directory, which varies by entry point.
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

# Served as it is, under its own name: a new school year brings a new file.
REGULATION_DOCUMENT: Final[Path] = DOCUMENTS_DIR / "Regolamento 26-27.pdf"

STATUTE_DOCUMENT: Final[Path] = DOCUMENTS_DIR / "Statuto Casa Michela.pdf"

# Printed from the iubenda texts; reprinted whenever iubenda changes.
TERMS_DOCUMENT: Final[Path] = DOCUMENTS_DIR / "Termini e Condizioni.pdf"
PRIVACY_DOCUMENT: Final[Path] = DOCUMENTS_DIR / "Privacy Policy.pdf"
COOKIE_DOCUMENT: Final[Path] = DOCUMENTS_DIR / "Cookie Policy.pdf"

# The app logo at twice the size emails draw it, reduced to a palette.
EMAIL_LOGO: Final[Path] = DOCUMENTS_DIR / "email_logo.png"

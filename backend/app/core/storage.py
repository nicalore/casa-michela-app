import hashlib
from io import BytesIO
from pathlib import Path
from typing import Final

from PIL import Image, ImageOps, UnidentifiedImageError

UPLOADS_DIR: Final[Path] = Path("uploads")

PROFILE_IMAGES_DIR: Final[Path] = UPLOADS_DIR / "profile-images"

# Must match the StaticFiles mount of UPLOADS_DIR, so both derive from the same path.
PROFILE_IMAGES_URL_PREFIX: Final[str] = f"/{PROFILE_IMAGES_DIR.as_posix()}"

# Avatars are drawn small: a phone photo shrinks to this before it is kept.
PROFILE_IMAGE_MAX_SIDE: Final[int] = 512
PROFILE_IMAGE_QUALITY: Final[int] = 85

INVALID_IMAGE_ERROR: Final[str] = "Sono ammesse solo immagini JPEG, PNG e WEBP"


# Shrunk, flattened onto white and named after its content, so a URL always
# serves the same bytes and may be cached for good; the previous file goes.
def store_profile_image(tax_code: str, previous_url: str | None, content: bytes) -> str:
    try:
        with Image.open(BytesIO(content)) as image:
            oriented = ImageOps.exif_transpose(image).convert("RGBA")

    except UnidentifiedImageError:
        raise ValueError(INVALID_IMAGE_ERROR) from None

    flattened = Image.new("RGB", oriented.size, "white")
    flattened.paste(oriented, mask=oriented.getchannel("A"))
    flattened.thumbnail((PROFILE_IMAGE_MAX_SIDE, PROFILE_IMAGE_MAX_SIDE))

    PROFILE_IMAGES_DIR.mkdir(parents=True, exist_ok=True)

    if previous_url is not None:
        (PROFILE_IMAGES_DIR / Path(previous_url).name).unlink(missing_ok=True)

    digest = hashlib.sha256(content).hexdigest()[:12]
    filename = f"{tax_code}-{digest}.jpg"
    flattened.save(
        PROFILE_IMAGES_DIR / filename,
        format="JPEG",
        quality=PROFILE_IMAGE_QUALITY,
        optimize=True,
    )

    return f"{PROFILE_IMAGES_URL_PREFIX}/{filename}"

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

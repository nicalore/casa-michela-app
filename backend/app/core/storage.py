from pathlib import Path
from typing import Final

UPLOADS_DIR: Final[Path] = Path("uploads")

PROFILE_IMAGES_DIR: Final[Path] = UPLOADS_DIR / "profile-images"

# Public prefix of the images: it has to match the StaticFiles mount of
# UPLOADS_DIR, so both are derived from the same path.
PROFILE_IMAGES_URL_PREFIX: Final[str] = f"/{PROFILE_IMAGES_DIR.as_posix()}"
"""Shrink the profile images already on disk to the avatar size, in place.

Run from backend/: uv run python -m scripts.shrink_profile_images
"""

from PIL import Image, ImageOps

from app.core.storage import (
    PROFILE_IMAGE_MAX_SIDE,
    PROFILE_IMAGE_QUALITY,
    PROFILE_IMAGES_DIR,
)


def main() -> None:
    for path in sorted(PROFILE_IMAGES_DIR.iterdir()):
        if not path.is_file():
            continue

        with Image.open(path) as image:
            image_format = image.format
            oriented = ImageOps.exif_transpose(image)

        before = oriented.size
        oriented.thumbnail((PROFILE_IMAGE_MAX_SIDE, PROFILE_IMAGE_MAX_SIDE))

        if oriented.size == before:
            print(f"{path.name}: {before[0]}x{before[1]}, kept")
            continue

        # Same name and format: the URLs in the database stay valid.
        options = {"quality": PROFILE_IMAGE_QUALITY} if image_format in ("JPEG", "WEBP") else {}
        oriented.save(path, format=image_format, **options)
        print(f"{path.name}: {before[0]}x{before[1]} -> {oriented.size[0]}x{oriented.size[1]}")


if __name__ == "__main__":
    main()

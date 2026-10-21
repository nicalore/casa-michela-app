"""Profile images under random names, served by their own route

Revision ID: b7e3c1f9a2d4
Revises: a6d4f2c8e913
Create Date: 2026-10-20
"""

import hashlib
import secrets
import shutil
from pathlib import Path, PurePosixPath

import sqlalchemy as sa

from alembic import op

revision = "b7e3c1f9a2d4"
down_revision = "a6d4f2c8e913"
branch_labels = None
depends_on = None

# The app runs from backend/, where its uploads folder lives.
_IMAGES_DIR = Path(__file__).resolve().parents[2] / "uploads" / "profile-images"

_OLD_PREFIX = "/uploads/profile-images"
_NEW_PREFIX = "/profile-images"


def _photos(prefix: str) -> list[tuple[str, str]]:
    rows = op.get_bind().execute(
        sa.text(
            "SELECT tax_code, profile_image_url FROM people "
            "WHERE profile_image_url LIKE :pattern"
        ),
        {"pattern": f"{prefix}/%"},
    )

    return [(tax_code, url) for tax_code, url in rows]


def _point(tax_code: str, url: str | None) -> None:
    op.get_bind().execute(
        sa.text("UPDATE people SET profile_image_url = :url WHERE tax_code = :code"),
        {"url": url, "code": tax_code},
    )


# Copied, not moved: another database may share the folder and name the old file.
def upgrade() -> None:
    for tax_code, url in _photos(_OLD_PREFIX):
        source = _IMAGES_DIR / PurePosixPath(url).name

        if not source.is_file():
            _point(tax_code, None)
            continue

        name = f"{secrets.token_hex(16)}.jpg"
        shutil.copyfile(source, _IMAGES_DIR / name)
        _point(tax_code, f"{_NEW_PREFIX}/{name}")


def downgrade() -> None:
    for tax_code, url in _photos(_NEW_PREFIX):
        source = _IMAGES_DIR / PurePosixPath(url).name

        if not source.is_file():
            _point(tax_code, None)
            continue

        digest = hashlib.sha256(source.read_bytes()).hexdigest()[:12]
        name = f"{tax_code}-{digest}.jpg"
        shutil.copyfile(source, _IMAGES_DIR / name)
        _point(tax_code, f"{_OLD_PREFIX}/{name}")

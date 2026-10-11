from enum import StrEnum
from typing import Final

from sqlalchemy import CheckConstraint, ForeignKey, Integer, String
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.constraints import not_blank_constraints
from app.models.mixins import UpdatedAtMixin

TOUR_SLUG_LENGTH: Final[int] = 120


class TourPlatformEnum(StrEnum):
    MOBILE = "MOBILE"
    DESKTOP = "DESKTOP"


# The latest version of a tutorial tour an account has seen, kept apart per platform.
class SeenTour(UpdatedAtMixin, Base):
    __tablename__ = "seen_tours"

    __table_args__ = (
        *not_blank_constraints("slug"),
        CheckConstraint("version > 0", name="version_positive"),
    )

    account_tax_code: Mapped[str] = mapped_column(
        ForeignKey("accounts.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    platform: Mapped[TourPlatformEnum] = mapped_column(
        SqlEnum(TourPlatformEnum, name="tour_platform_enum"),
        primary_key=True,
    )

    slug: Mapped[str] = mapped_column(String(TOUR_SLUG_LENGTH), primary_key=True)

    version: Mapped[int] = mapped_column(Integer, nullable=False)

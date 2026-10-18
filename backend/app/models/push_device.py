from enum import StrEnum
from typing import Final

from sqlalchemy import CheckConstraint, ForeignKey, Integer, String
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.constraints import not_blank_constraints
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

PUSH_ADDRESS_LENGTH: Final[int] = 2048
PUSH_KEY_LENGTH: Final[int] = 200


class PushPlatformEnum(StrEnum):
    WEB = "WEB"
    ANDROID = "ANDROID"
    IOS = "IOS"


# Where an account's notifications are pushed: a browser subscription or an app token.
class PushDevice(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "push_devices"

    __table_args__ = (
        *not_blank_constraints("address"),
        CheckConstraint(
            "platform <> 'WEB' OR (p256dh IS NOT NULL AND auth IS NOT NULL)",
            name="web_keys_present",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    account_tax_code: Mapped[str] = mapped_column(
        ForeignKey("accounts.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    platform: Mapped[PushPlatformEnum] = mapped_column(
        SqlEnum(PushPlatformEnum, name="push_platform_enum"),
        nullable=False,
    )

    # The browser's endpoint URL, or the app's token.
    address: Mapped[str] = mapped_column(
        String(PUSH_ADDRESS_LENGTH),
        unique=True,
        nullable=False,
    )

    # The sign-in that registered it: pushed to only while that session lives.
    session_id: Mapped[str] = mapped_column(String(36), nullable=False)

    # The browser's keys that encrypt what is pushed to it.
    p256dh: Mapped[str | None] = mapped_column(String(PUSH_KEY_LENGTH))

    auth: Mapped[str | None] = mapped_column(String(PUSH_KEY_LENGTH))

from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import not_blank_constraints
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.account import Account


class TokenTypeEnum(StrEnum):
    REFRESH = "REFRESH"
    PASSWORD_RESET = "PASSWORD_RESET"


class DeviceTypeEnum(StrEnum):
    DESKTOP = "DESKTOP"
    PHONE = "PHONE"
    TABLET = "TABLET"
    UNKNOWN = "UNKNOWN"


class RefreshToken(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "refresh_tokens"

    __table_args__ = (
        CheckConstraint(
            "expires_at > created_at",
            name="refresh_token_expiration_after_creation",
        ),
        *not_blank_constraints(
            "token_id",
            "token_hash",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    account_tax_code: Mapped[str] = mapped_column(
        ForeignKey("accounts.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    token_id: Mapped[str] = mapped_column(
        String(36),
        unique=True,
        nullable=False,
        index=True,
    )

    token_hash: Mapped[str] = mapped_column(String(512), nullable=False)

    token_type: Mapped[TokenTypeEnum] = mapped_column(
        SqlEnum(TokenTypeEnum, name="token_type_enum"),
        nullable=False,
        default=TokenTypeEnum.REFRESH,
        server_default="REFRESH",
    )

    # Shared by every token of one sign-in: rotation carries it over, so a
    # session can be listed and revoked as a whole.
    session_id: Mapped[str] = mapped_column(
        String(36),
        nullable=False,
        index=True,
    )

    # The sign-in that opened the session; rotation carries it over too.
    logged_in_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    device_type: Mapped[DeviceTypeEnum] = mapped_column(
        SqlEnum(DeviceTypeEnum, name="device_type_enum"),
        nullable=False,
        default=DeviceTypeEnum.UNKNOWN,
        server_default="UNKNOWN",
    )

    # "Chrome su macOS", "App iOS": read off the request that signed in.
    device_name: Mapped[str | None] = mapped_column(String(120), nullable=True)

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    account: Mapped[Account] = relationship(back_populates="refresh_tokens")
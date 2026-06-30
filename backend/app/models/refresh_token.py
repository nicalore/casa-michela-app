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
    func,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.account import Account

class TokenTypeEnum(StrEnum):
    REFRESH = "REFRESH"
    PASSWORD_RESET = "PASSWORD_RESET"

class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    __table_args__ = (
        CheckConstraint(
            "length(trim(token_id)) > 0",
            name="token_id_not_blank",
        ),
        CheckConstraint(
            "length(trim(token_hash)) > 0",
            name="token_hash_not_blank",
        ),
        CheckConstraint(
            "expires_at > created_at",
            name="refresh_token_expiration_after_creation",
        ),
    )

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    account_tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "accounts.tax_code",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    token_id: Mapped[str] = mapped_column(
        String(36),
        unique=True,
        nullable=False,
        index=True,
    )

    token_hash: Mapped[str] = mapped_column(
        String(512),
        nullable=False,
    )

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    account: Mapped[Account] = relationship(
        back_populates="refresh_tokens",
    )

    token_type: Mapped[TokenTypeEnum] = mapped_column(
        SqlEnum(TokenTypeEnum, name="token_type_enum"),
        nullable=False,
        default=TokenTypeEnum.REFRESH,
        server_default="REFRESH",
    )
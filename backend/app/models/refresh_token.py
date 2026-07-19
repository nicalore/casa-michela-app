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
        ForeignKey("accounts.tax_code", ondelete="CASCADE"),
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

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    account: Mapped[Account] = relationship(back_populates="refresh_tokens")
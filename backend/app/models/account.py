from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    String,
    func,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints

if TYPE_CHECKING:
    from app.models.person import Person


class AccountStatusEnum(StrEnum):
    ACTIVE = "ACTIVE"
    DISABLED = "DISABLED"


class Account(Base):
    __tablename__ = "accounts"

    __table_args__ = (
        CheckConstraint(
            "failed_login_attempts >= 0",
            name="failed_login_attempts_non_negative",
        ),
        CheckConstraint(
            """
            locked_until IS NULL
            OR last_failed_login_attempt IS NULL
            OR locked_until >= last_failed_login_attempt
            """,
            name="locked_until_after_failed_attempt",
        ),
        CheckConstraint(
            """
            last_login IS NULL
            OR last_login >= created_at
            """,
            name="last_login_after_creation",
        ),
        CheckConstraint(
            "length(trim(username)) > 0",
            name="username_not_blank",
        ),
        CheckConstraint(
        """
        last_login IS NOT NULL
        OR password_reset_required = TRUE
        """,
        name="first_login_requires_password_reset",
        ),
        CheckConstraint(
            "length(trim(password_hash)) > 0",
            name="password_hash_not_blank",
        ),

        *no_surrounding_whitespace_constraints(
            "tax_code",
            "username",
            "password_hash",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "people.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    username: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        nullable=False,
        index=True,
    )

    status: Mapped[AccountStatusEnum] = mapped_column(
        SqlEnum(
            AccountStatusEnum,
            name="account_status_enum",
        ),
        nullable=False,
    )

    password_hash: Mapped[str] = mapped_column(
        String(512),
        nullable=False,
    )

    failed_login_attempts: Mapped[int] = mapped_column(
        nullable=False,
        default=0,
        server_default="0",
    )

    last_failed_login_attempt: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    locked_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    last_login: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    password_reset_required: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
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

    person: Mapped[Person] = relationship(
        back_populates="account",
        uselist=False,
    )
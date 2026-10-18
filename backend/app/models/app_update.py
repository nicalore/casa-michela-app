from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    LargeBinary,
    String,
    UniqueConstraint,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, deferred, mapped_column, relationship
from sqlalchemy.sql import func

from app.core import field_lengths
from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_constraints,
)
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.person import Person


# The roles that have an area of their own in the app.
class AppUpdateRoleEnum(StrEnum):
    ADMIN = "ADMIN"
    TEACHER = "TEACHER"
    PSYCHOLOGIST = "PSYCHOLOGIST"
    PARENT = "PARENT"
    STUDENT = "STUDENT"


# What changed in the app, shown once to everyone holding one of its roles.
class AppUpdate(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "app_updates"

    __table_args__ = (
        *not_blank_constraints("title", "message", "version"),
        *no_surrounding_whitespace_constraints("title", "message", "version"),
        CheckConstraint("cardinality(recipients) > 0", name="recipients_not_empty"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    # The person, not the administrator row: an update outlives its author's role.
    author_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("people.tax_code", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    title: Mapped[str] = mapped_column(
        String(field_lengths.NOTICE_TITLE),
        nullable=False,
    )

    # Markdown; an inline image is written ![](image:<key>), the key of its file.
    message: Mapped[str] = mapped_column(
        String(field_lengths.NOTICE_MESSAGE),
        nullable=False,
    )

    # The app's own, as x.y.z, taken from the client that published it.
    version: Mapped[str] = mapped_column(
        String(field_lengths.APP_VERSION),
        nullable=False,
    )

    recipients: Mapped[list[AppUpdateRoleEnum]] = mapped_column(
        ARRAY(SqlEnum(AppUpdateRoleEnum, name="app_update_role_enum")),
        nullable=False,
    )

    # Only an edit sets it: updated_at also moves for the token.
    edited_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    author: Mapped[Person] = relationship(viewonly=True)

    images: Mapped[list[AppUpdateImage]] = relationship(
        cascade="all, delete-orphan",
        order_by="AppUpdateImage.id",
    )


# An image of an update's message.
class AppUpdateImage(CreatedAtMixin, Base):
    __tablename__ = "app_update_images"

    __table_args__ = (
        UniqueConstraint("update_id", "image_key"),
        CheckConstraint("size >= 0", name="size_not_negative"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    update_id: Mapped[int] = mapped_column(
        ForeignKey("app_updates.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    image_key: Mapped[str] = mapped_column(String(36), nullable=False)

    content_type: Mapped[str] = mapped_column(String(255), nullable=False)

    size: Mapped[int] = mapped_column(Integer, nullable=False)

    content: Mapped[bytes] = deferred(mapped_column(LargeBinary, nullable=False))


# Each reader's own: read once, never shown to them again, edited or not.
class AppUpdateRead(Base):
    __tablename__ = "app_update_reads"

    update_id: Mapped[int] = mapped_column(
        ForeignKey("app_updates.id", ondelete="CASCADE"),
        primary_key=True,
    )

    account_tax_code: Mapped[str] = mapped_column(
        ForeignKey("accounts.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    read_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Date,
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


# MEMBER is any enrolled member; PARENT only parents of enrolled pupils.
class NoticeRoleEnum(StrEnum):
    ADMIN = "ADMIN"
    TEACHER = "TEACHER"
    PSYCHOLOGIST = "PSYCHOLOGIST"
    PARENT = "PARENT"
    STUDENT = "STUDENT"
    COURSE_PARTICIPANT = "COURSE_PARTICIPANT"
    MEMBER = "MEMBER"


# An administrator's message to everyone holding some roles, mailed on sending.
class Notice(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "notices"

    __table_args__ = (
        *not_blank_constraints("title", "message"),
        *no_surrounding_whitespace_constraints("title", "message"),
        CheckConstraint("cardinality(recipients) > 0", name="recipients_not_empty"),
        CheckConstraint("recipient_count >= 0", name="recipient_count_not_negative"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    # The person, not the administrator row: a notice outlives its author's role.
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

    recipients: Mapped[list[NoticeRoleEnum]] = mapped_column(
        ARRAY(SqlEnum(NoticeRoleEnum, name="notice_role_enum")),
        nullable=False,
    )

    # People reached by the last sending, counted then.
    recipient_count: Mapped[int] = mapped_column(Integer, nullable=False)

    # Only an author's edit sets it: updated_at also moves for the token.
    edited_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    author: Mapped[Person] = relationship(viewonly=True)

    files: Mapped[list[NoticeFile]] = relationship(
        back_populates="notice",
        cascade="all, delete-orphan",
        order_by="NoticeFile.id",
    )

    pin: Mapped[NoticePin | None] = relationship(
        back_populates="notice",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


# An attachment, or an image of the message when image_key is set.
class NoticeFile(CreatedAtMixin, Base):
    __tablename__ = "notice_files"

    __table_args__ = (
        UniqueConstraint("notice_id", "image_key"),
        *not_blank_constraints("file_name"),
        CheckConstraint("size >= 0", name="size_not_negative"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    notice_id: Mapped[int] = mapped_column(
        ForeignKey("notices.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    file_name: Mapped[str] = mapped_column(
        String(field_lengths.FILE_NAME),
        nullable=False,
    )

    content_type: Mapped[str] = mapped_column(String(255), nullable=False)

    size: Mapped[int] = mapped_column(Integer, nullable=False)

    image_key: Mapped[str | None] = mapped_column(String(36), nullable=True)

    # In the database, not on disk: rows and bytes come and go in one transaction.
    content: Mapped[bytes] = deferred(mapped_column(LargeBinary, nullable=False))

    notice: Mapped[Notice] = relationship(back_populates="files")


# Any administrator pins; its own table, so the author's edit token stays put.
class NoticePin(Base):
    __tablename__ = "notice_pins"

    notice_id: Mapped[int] = mapped_column(
        ForeignKey("notices.id", ondelete="CASCADE"),
        primary_key=True,
    )

    pinned_by_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("people.tax_code", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    pinned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Last day pinned, None for good; a day gone by stops counting, never swept.
    until: Mapped[date | None] = mapped_column(Date, nullable=True)

    notice: Mapped[Notice] = relationship(back_populates="pin")

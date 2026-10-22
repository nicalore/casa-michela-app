from __future__ import annotations

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Integer,
    LargeBinary,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, deferred, mapped_column

from app.db.base import Base
from app.models.mixins import CreatedAtMixin


# An image of a technical, methodological or administrator's note: ![](image:<key>).
class StudentNoteImage(CreatedAtMixin, Base):
    __tablename__ = "student_note_images"

    __table_args__ = (
        UniqueConstraint("technical_note_id", "image_key"),
        UniqueConstraint("methodological_note_id", "image_key"),
        UniqueConstraint("administrator_note_id", "image_key"),
        CheckConstraint(
            "num_nonnulls(technical_note_id, methodological_note_id, "
            "administrator_note_id) = 1",
            name="one_note",
        ),
        CheckConstraint("size >= 0", name="size_not_negative"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    technical_note_id: Mapped[int | None] = mapped_column(
        ForeignKey("technical_notes.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    methodological_note_id: Mapped[int | None] = mapped_column(
        ForeignKey("methodological_notes.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    administrator_note_id: Mapped[int | None] = mapped_column(
        ForeignKey("administrator_notes.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    image_key: Mapped[str] = mapped_column(String(36), nullable=False)

    content_type: Mapped[str] = mapped_column(String(255), nullable=False)

    size: Mapped[int] = mapped_column(Integer, nullable=False)

    content: Mapped[bytes] = deferred(mapped_column(LargeBinary, nullable=False))

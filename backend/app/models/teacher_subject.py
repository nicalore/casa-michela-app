from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.subject import Subject
    from app.models.teacher import Teacher


class TeacherSubject(Base):
    __tablename__ = "teacher_subjects"

    teacher_tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "teachers.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    subject_id: Mapped[int] = mapped_column(
        ForeignKey(
            "subjects.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    teacher: Mapped[Teacher] = relationship(
        back_populates="teacher_subjects",
    )

    subject: Mapped[Subject] = relationship(
        back_populates="teacher_subjects",
    )
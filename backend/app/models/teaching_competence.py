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
    from app.models.teaching_offering import TeachingOffering


class TeachingCompetence(Base):
    __tablename__ = "teaching_competences"

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

    teaching_offering_id: Mapped[int] = mapped_column(
        ForeignKey(
            "teaching_offerings.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    teacher: Mapped[Teacher] = relationship(
        back_populates="teaching_competences",
    )

    subject: Mapped[Subject] = relationship(
        back_populates="teaching_competences",
    )

    teaching_offering: Mapped[TeachingOffering] = relationship(
        back_populates="teaching_competences",
    )
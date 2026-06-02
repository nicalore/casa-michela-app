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
    from app.models.teaching_offering import TeachingOffering


class TeachingOfferingSubject(Base):
    __tablename__ = "teaching_offering_subjects"

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

    subject: Mapped[Subject] = relationship(
        back_populates="teaching_offering_subjects",
    )

    teaching_offering: Mapped[TeachingOffering] = relationship(
        back_populates="teaching_offering_subjects",
    )

from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    ForeignKey,
    Integer,
)
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.association_subject import AssociationSubject
    from app.models.ministry_subject import MinistrySubject


class MinistryAssociationSubject(Base):
    __tablename__ = "ministry_association_subjects"

    ministry_subject_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(
            "ministry_subjects.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    association_subject_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(
            "association_subjects.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    ministry_subject: Mapped[MinistrySubject] = relationship(
        back_populates="ministry_association_subjects",
    )

    association_subject: Mapped[AssociationSubject] = relationship(
        back_populates="ministry_association_subjects",
    )
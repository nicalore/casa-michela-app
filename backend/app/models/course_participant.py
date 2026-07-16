from __future__ import annotations

from datetime import date
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.member import Member


class CourseTypeEnum(StrEnum):
    YOGA = "YOGA"
    PILATES = "PILATES"


class CourseParticipant(Base):
    __tablename__ = "course_participants"

    __table_args__ = (
        CheckConstraint(
            "medical_certificate_expiration > DATE '1900-01-01'",
            name="medical_certificate_expiration_min",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "members.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    medical_certificate_expiration: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    course_type: Mapped[CourseTypeEnum] = mapped_column(
        SqlEnum(
            CourseTypeEnum,
            name="course_type_enum",
        ),
        nullable=False,
    )

    member: Mapped[Member] = relationship(
        back_populates="course_participant_profile",
        uselist=False,
    )
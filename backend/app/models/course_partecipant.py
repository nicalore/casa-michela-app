from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    String,
)
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints

if TYPE_CHECKING:
    from app.models.member import Member


class CoursePartecipant(Base):
    __tablename__ = "course_partecipants"

    __table_args__ = (
        CheckConstraint(
            "medical_certificate_expiration > DATE '1900-01-01'",
            name="medical_certificate_expiration_min",
        ),
        CheckConstraint(
            "length(trim(course_type)) > 0",
            name="course_type_not_blank",
        ),
        *no_surrounding_whitespace_constraints(
            "course_type",
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

    course_type: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    member: Mapped[Member] = relationship(
        back_populates="course_partecipant_profile",
        uselist=False,
    )
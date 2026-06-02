from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Integer,
    UniqueConstraint,
    event,
)
from sqlalchemy.orm import (
    Mapped,
    Session,
    mapped_column,
    relationship,
)

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.student import Student
    from app.models.teaching_offering import TeachingOffering


class SchoolEnrollment(Base):
    __tablename__ = "school_enrollments"

    __table_args__ = (
        UniqueConstraint(
            "student_tax_code",
            "start_year",
            name="uq_student_school_year",
        ),
        CheckConstraint(
            "start_year >= 1900",
            name="school_enrollment_start_year_min",
        ),
        CheckConstraint(
            "grade > 0",
            name="positive_grade",
        ),
    )

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    start_year: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    grade: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    student_tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "students.tax_code",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    teaching_offering_id: Mapped[int] = mapped_column(
        ForeignKey(
            "teaching_offerings.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
        index=True,
    )

    student: Mapped[Student] = relationship(
        back_populates="school_enrollments",
    )

    teaching_offering: Mapped[TeachingOffering] = relationship(
        back_populates="school_enrollments",
    )


@event.listens_for(Session, "before_flush")
def _validate_school_enrollments(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.models.teaching_offering import TeachingOffering

    for obj in session.new.union(session.dirty):
        if not isinstance(obj, SchoolEnrollment):
            continue

        offering = obj.teaching_offering

        if offering is None:
            offering = session.get(
                TeachingOffering,
                obj.teaching_offering_id,
            )

        if offering is None:
            continue

        valid_years = {
            offering_year.year
            for offering_year in offering.years
        }

        if obj.grade not in valid_years:
            raise ValueError(
                "School enrollment grade is not compatible "
                "with the selected teaching offering"
            )
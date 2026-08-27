from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING, Final

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    Numeric,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_when_present_constraints,
)
from app.models.mixins import UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.availability import Availability
    from app.models.staff import Staff
    from app.models.teacher_service import TeacherService
    from app.models.teaching_competence import TeachingCompetence


# Teacher rating, 0 to 5 in half-point steps.
RATING_MINIMUM: Final[Decimal] = Decimal("0")
RATING_MAXIMUM: Final[Decimal] = Decimal("5")
RATING_STEP: Final[Decimal] = Decimal("0.5")

# Default for a not-yet-rated teacher: above the midpoint on purpose.
RATING_DEFAULT: Final[Decimal] = Decimal("3.5")


class Teacher(UpdatedAtMixin, Base):
    __tablename__ = "teachers"

    __table_args__ = (
        # A still-in-high-school teacher cannot have university education set.
        CheckConstraint(
            "NOT is_high_school_student OR university_education IS NULL",
            name="high_school_student_has_no_university_education",
        ),
        CheckConstraint(
            f"rating BETWEEN {RATING_MINIMUM} AND {RATING_MAXIMUM}",
            name="rating_within_bounds",
        ),
        CheckConstraint(
            f"rating % {RATING_STEP} = 0",
            name="rating_in_half_points",
        ),
        *not_blank_when_present_constraints(
            "school_education",
            "university_education",
        ),
        *no_surrounding_whitespace_constraints(
            "school_education",
            "university_education",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey("staff.tax_code", ondelete="CASCADE"),
        primary_key=True,
    )

    # False means university or beyond — the right value for pre-existing rows.
    is_high_school_student: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    school_education: Mapped[str | None] = mapped_column(String(500), nullable=True)

    university_education: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Numeric, not float: binary rounding would miscount half points.
    rating: Mapped[Decimal] = mapped_column(
        Numeric(2, 1),
        nullable=False,
        default=RATING_DEFAULT,
        server_default=str(RATING_DEFAULT),
    )

    staff_member: Mapped[Staff] = relationship(
        back_populates="teacher_profile",
        uselist=False,
    )

    teaching_competences: Mapped[list[TeachingCompetence]] = relationship(
        back_populates="teacher",
        cascade="all, delete-orphan",
    )

    teacher_services: Mapped[list[TeacherService]] = relationship(
        back_populates="teacher",
        cascade="all, delete-orphan",
    )

    availabilities: Mapped[list[Availability]] = relationship(
        back_populates="teacher",
        cascade="all, delete-orphan",
    )

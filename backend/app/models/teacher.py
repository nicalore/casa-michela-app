from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING, Final

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    String,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_when_present_constraints,
)
from app.models.mixins import UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.administrator_note import AdministratorNote
    from app.models.availability import Availability
    from app.models.staff import Staff
    from app.models.teacher_service import TeacherService
    from app.models.teaching_competence import TeachingCompetence


# What the administrators judge a teacher on; mirrored by kCriteria in the frontend.
TEACHER_CRITERIA: Final[tuple[str, ...]] = (
    "competence",
    "clarity",
    "empathy",
    "motivation",
    "relationship",
    "transparency",
    "flexibility",
    "proactivity",
    "reliability",
    "rules",
)

CRITERION_POINTS: Final[Decimal] = Decimal("0.5")

_CRITERION_LENGTH: Final[int] = 20


class Teacher(UpdatedAtMixin, Base):
    __tablename__ = "teachers"

    __table_args__ = (
        CheckConstraint(
            "NOT is_high_school_student OR university_education IS NULL",
            name="high_school_student_has_no_university_education",
        ),
        CheckConstraint(
            "met_criteria <@ ARRAY["
            + ", ".join(f"'{key}'" for key in TEACHER_CRITERIA)
            + "]::varchar[]",
            name="met_criteria_known",
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
        ForeignKey("staff.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    is_high_school_student: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    school_education: Mapped[str | None] = mapped_column(String(500), nullable=True)

    university_education: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # The criteria the administrators judged met; a new teacher meets none.
    met_criteria: Mapped[list[str]] = mapped_column(
        ARRAY(String(_CRITERION_LENGTH)),
        nullable=False,
        default=list,
        server_default="{}",
    )

    staff_member: Mapped[Staff] = relationship(
        back_populates="teacher_profile",
        uselist=False,
    )

    # What the teacher can do today; closed rows are history for the ranking.
    teaching_competences: Mapped[list[TeachingCompetence]] = relationship(
        primaryjoin=(
            "and_(Teacher.tax_code == TeachingCompetence.teacher_tax_code, "
            "TeachingCompetence.valid_to.is_(None))"
        ),
        viewonly=True,
    )

    teacher_services: Mapped[list[TeacherService]] = relationship(
        primaryjoin=(
            "and_(Teacher.tax_code == TeacherService.teacher_tax_code, "
            "TeacherService.valid_to.is_(None))"
        ),
        viewonly=True,
    )

    availabilities: Mapped[list[Availability]] = relationship(
        back_populates="teacher",
        cascade="all, delete-orphan",
    )

    administrator_notes: Mapped[list[AdministratorNote]] = relationship(
        back_populates="teacher",
        cascade="all, delete-orphan",
        order_by="[AdministratorNote.created_at.desc(), AdministratorNote.id.desc()]",
    )

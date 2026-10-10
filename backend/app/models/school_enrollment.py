from __future__ import annotations

from typing import TYPE_CHECKING, Final

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    ForeignKeyConstraint,
    Integer,
    UniqueConstraint,
    event,
)
from sqlalchemy.orm import Mapped, Session, mapped_column, relationship

from app.core.labels import HOMESCHOOLING_LABEL
from app.db.base import Base

if TYPE_CHECKING:
    from app.models.school_study_program import SchoolStudyProgram
    from app.models.student import Student
    from app.models.study_program import StudyProgram

_INCOMPATIBLE_GRADE_ERROR: Final[str] = (
    "La classe selezionata non è compatibile con il percorso di studi."
)


class SchoolEnrollment(Base):
    __tablename__ = "school_enrollments"

    __table_args__ = (
        UniqueConstraint(
            "student_tax_code",
            "start_year",
            name="uq_student_school_year",
        ),
        CheckConstraint("start_year >= 1900", name="school_enrollment_start_year_min"),
        CheckConstraint("grade > 0", name="positive_grade"),
        CheckConstraint(
            "homeschooling = (school_id IS NULL)",
            name="school_or_homeschooling",
        ),
        # Not checked under homeschooling: a NULL school_id skips the whole pair.
        ForeignKeyConstraint(
            ["study_program_id", "school_id"],
            [
                "school_study_programs.study_program_id",
                "school_study_programs.school_id",
            ],
            ondelete="RESTRICT",
            name="school_enrollments_ssp_fkey",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    start_year: Mapped[int] = mapped_column(Integer, nullable=False)

    grade: Mapped[int] = mapped_column(Integer, nullable=False)

    student_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("students.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    study_program_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("study_programs.id", ondelete="RESTRICT"),
        nullable=False,
    )

    # Null under homeschooling, which has no school.
    school_id: Mapped[int | None] = mapped_column(Integer, nullable=True)

    homeschooling: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )

    student: Mapped[Student] = relationship(back_populates="school_enrollments")

    # None under homeschooling.
    school_study_program: Mapped[SchoolStudyProgram | None] = relationship(
        back_populates="school_enrollments",
    )

    # Direct: homeschooling has no school_study_program to reach it through.
    study_program: Mapped[StudyProgram] = relationship(viewonly=True)

    @property
    def school_label(self) -> str:
        if self.homeschooling or self.school_study_program is None:
            return HOMESCHOOLING_LABEL

        return self.school_study_program.school.name


@event.listens_for(Session, "before_flush")
def _validate_school_enrollments(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.models.study_program import StudyProgram

    for instance in session.new.union(session.dirty):
        if not isinstance(instance, SchoolEnrollment):
            continue

        # By id: a pending row has nothing loaded, and homeschooling no pair at all.
        program = session.get(StudyProgram, instance.study_program_id)

        if program is None:
            continue

        if not (program.min_year <= instance.grade <= program.max_year):
            raise ValueError(_INCOMPATIBLE_GRADE_ERROR)
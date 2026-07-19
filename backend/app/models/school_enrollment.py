from __future__ import annotations

from typing import TYPE_CHECKING, Final

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    ForeignKeyConstraint,
    Integer,
    UniqueConstraint,
    event,
)
from sqlalchemy.orm import Mapped, Session, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.school_study_program import SchoolStudyProgram
    from app.models.student import Student

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

    study_program_id: Mapped[int] = mapped_column(Integer, nullable=False)

    school_id: Mapped[int] = mapped_column(Integer, nullable=False)

    student: Mapped[Student] = relationship(back_populates="school_enrollments")

    school_study_program: Mapped[SchoolStudyProgram] = relationship(
        back_populates="school_enrollments",
    )


@event.listens_for(Session, "before_flush")
def _validate_school_enrollments(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.models.school_study_program import SchoolStudyProgram

    for instance in session.new.union(session.dirty):
        if not isinstance(instance, SchoolEnrollment):
            continue

        school_study_program = instance.school_study_program

        if school_study_program is None:
            # The tuple order must match the primary key column order of the mapper.
            school_study_program = session.get(
                SchoolStudyProgram,
                (instance.study_program_id, instance.school_id),
            )

        if school_study_program is None or school_study_program.study_program is None:
            continue

        program = school_study_program.study_program

        if not (program.min_year <= instance.grade <= program.max_year):
            raise ValueError(_INCOMPATIBLE_GRADE_ERROR)
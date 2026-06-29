from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    ForeignKeyConstraint,
    Integer,
    String,
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
    from app.models.school_study_program import SchoolStudyProgram
    from app.models.student import Student


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
        ForeignKeyConstraint(
            ["study_program_id", "school_mechanographic_code"],
            ["school_study_programs.study_program_id", "school_study_programs.school_mechanographic_code"],
            ondelete="RESTRICT",
            onupdate="CASCADE",
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
            onupdate="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    study_program_id: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    school_mechanographic_code: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    student: Mapped[Student] = relationship(
        back_populates="school_enrollments",
    )

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

    for obj in session.new.union(session.dirty):
        if not isinstance(obj, SchoolEnrollment):
            continue

        ssp = obj.school_study_program

        if ssp is None:
            ssp = session.get(
                SchoolStudyProgram,
                (obj.study_program_id, obj.school_mechanographic_code),
            )

        if ssp is None or ssp.study_program is None:
            continue

        program = ssp.study_program

        if not (program.min_year <= obj.grade <= program.max_year):
            raise ValueError(
                "La classe selezionata non è compatibile con il percorso di studi."
            )
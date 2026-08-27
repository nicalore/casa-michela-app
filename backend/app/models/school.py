from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints
from app.models.mixins import CreatedAtMixin

if TYPE_CHECKING:
    from app.models.school_study_program import SchoolStudyProgram
    from app.models.study_program import StudyProgram


class School(CreatedAtMixin, Base):
    __tablename__ = "schools"

    __table_args__ = (
        UniqueConstraint("name", "city", name="uq_school_name_city"),
        CheckConstraint("province ~ '^[A-Z]{2}$'", name="school_province_format"),
        CheckConstraint("length(trim(name)) > 0", name="school_name_not_blank"),
        CheckConstraint("length(trim(city)) > 0", name="school_city_not_blank"),
        *no_surrounding_whitespace_constraints(
            "mechanographic_code",
            "name",
            "city",
            "province",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    # Generous: some institutes hold one official code per site or level.
    mechanographic_code: Mapped[str | None] = mapped_column(String(100), nullable=True)

    name: Mapped[str] = mapped_column(String(255), nullable=False)

    city: Mapped[str] = mapped_column(String(100), nullable=False)

    province: Mapped[str] = mapped_column(String(2), nullable=False)

    school_study_programs: Mapped[list[SchoolStudyProgram]] = relationship(
        back_populates="school",
        cascade="all, delete-orphan",
    )

    # Read-only view over the join table, for direct serialization.
    study_programs: Mapped[list[StudyProgram]] = relationship(
        "StudyProgram",
        secondary="school_study_programs",
        viewonly=True,
    )
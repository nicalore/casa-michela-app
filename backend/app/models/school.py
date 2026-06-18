from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
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
    from app.models.school_study_program import SchoolStudyProgram


class School(Base):
    __tablename__ = "schools"

    __table_args__ = (
        CheckConstraint(
            "province ~ '^[A-Z]{2}$'",
            name="school_province_format",
        ),
        #Must be 10 characters long if it does not start with PRIV-
        CheckConstraint(
            "mechanographic_code LIKE 'PRIV-%' OR length(mechanographic_code) = 10",
            name="school_code_length",
        ),
        #First two letters must match the province if it does not start with PRIV-
        CheckConstraint(
            """
            mechanographic_code LIKE 'PRIV-%' OR
            upper(substr(mechanographic_code, 1, 2)) = upper(province)
            """,
            name="school_code_province_consistency",
        ),
        CheckConstraint(
            "length(trim(name)) > 0",
            name="school_name_not_blank",
        ),
        CheckConstraint(
            "length(trim(city)) > 0",
            name="school_city_not_blank",
        ),
        *no_surrounding_whitespace_constraints(
            "mechanographic_code",
            "name",
            "city",
            "province",
        ),
    )

    mechanographic_code: Mapped[str] = mapped_column(
        String(20),
        primary_key=True,
    )

    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    city: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    province: Mapped[str] = mapped_column(
        String(2),
        nullable=False,
    )

    school_study_programs: Mapped[list[SchoolStudyProgram]] = relationship(
        back_populates="school",
        cascade="all, delete-orphan",
    )
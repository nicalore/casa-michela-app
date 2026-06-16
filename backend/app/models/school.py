from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints

if TYPE_CHECKING:
    from app.models.teaching_offering import TeachingOffering

class School(Base):
    __tablename__ = "schools"

    __table_args__ = (
        CheckConstraint(
            "province ~ '^[A-Z]{2}$'",
            name="school_province_format",
        ),
        # Se non inizia con PRIV-, deve essere di 10 caratteri
        CheckConstraint(
            "mechanographic_code LIKE 'PRIV-%' OR length(mechanographic_code) = 10",
            name="school_code_length",
        ),
        # Se non inizia con PRIV-, le prime due lettere devono corrispondere alla provincia
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

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    city: Mapped[str] = mapped_column(String(100), nullable=False)
    province: Mapped[str] = mapped_column(String(2), nullable=False)

    teaching_offerings: Mapped[list[TeachingOffering]] = relationship(
        back_populates="school",
    )

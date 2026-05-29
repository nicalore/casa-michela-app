from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    String,
    func,
)
from sqlalchemy import (
    Enum as SqlEnum,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class GenderEnum(StrEnum):
    M = "M"
    F = "F"


class ParentalResponsibilityEnum(StrEnum):
    DEPENDENT = "DEPENDENT"
    INDEPENDENT = "INDEPENDENT"


class Person(Base):
    __tablename__ = "people"

    __table_args__ = (
        CheckConstraint(
            "length(tax_code) = 16",
            name="tax_code_length",
        ),
        CheckConstraint(
            "tax_code = upper(tax_code)",
            name="tax_code_uppercase",
        ),
        CheckConstraint(
            "birth_date >= DATE '1900-01-01'",
            name="birth_date_min",
        ),
        CheckConstraint(
            "birth_date <= CURRENT_DATE",
            name="birth_date_max",
        ),
        CheckConstraint(
            "birth_province ~ '^[A-Za-z]{2}$'",
            name="birth_province_format",
        ),
        CheckConstraint(
            "residence_province ~ '^[A-Za-z]{2}$'",
            name="residence_province_format",
        ),
        CheckConstraint(
            "postal_code ~ '^[0-9]{5}$'",
            name="postal_code_format",
        ),
        CheckConstraint(
            "phone ~ '^\\+?[0-9]+$'",
            name="phone_format",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        String(16),
        primary_key=True,
    )

    first_name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    last_name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    gender: Mapped[GenderEnum] = mapped_column(
        SqlEnum(
            GenderEnum,
            name="gender_enum",
        ),
        nullable=False,
    )

    birth_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    birth_city: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    birth_province: Mapped[str] = mapped_column(
        String(2),
        nullable=False,
    )

    email: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
    )

    phone: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    parental_responsibility: Mapped[
        ParentalResponsibilityEnum
    ] = mapped_column(
        SqlEnum(
            ParentalResponsibilityEnum,
            name="parental_responsibility_enum",
        ),
        nullable=False,
    )

    residence_type: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    residence_address: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    residence_street_number: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    residence_city: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    residence_province: Mapped[str] = mapped_column(
        String(2),
        nullable=False,
    )

    postal_code: Mapped[str] = mapped_column(
        String(5),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    account: Mapped["Account | None"] = relationship(
    back_populates="person",
    uselist=False,
    )

    parental_relationships: Mapped[list["ParentalResponsibility"]] = relationship(
    back_populates="child",
    cascade="all, delete-orphan",
    )

    parent_profile: Mapped["Parent | None"] = relationship(
    back_populates="person",
    uselist=False,
    )

    member_profile: Mapped["Member | None"] = relationship(
    back_populates="person",
    uselist=False,
    )
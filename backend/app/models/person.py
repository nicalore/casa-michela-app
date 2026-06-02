from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    String,
    func,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship, validates

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints

if TYPE_CHECKING:
    from app.models.account import Account
    from app.models.member import Member
    from app.models.parent import Parent
    from app.models.parental_responsibility import ParentalResponsibility


class GenderEnum(StrEnum):
    M = "M"
    F = "F"


_TAX_CODE_ODD_POSITION_VALUES = {
    "0": 1, "1": 0, "2": 5, "3": 7, "4": 9,
    "5": 13, "6": 15, "7": 17, "8": 19, "9": 21,
    "A": 1, "B": 0, "C": 5, "D": 7, "E": 9,
    "F": 13, "G": 15, "H": 17, "I": 19, "J": 21,
    "K": 2, "L": 4, "M": 18, "N": 20, "O": 11,
    "P": 3, "Q": 6, "R": 8, "S": 12, "T": 14,
    "U": 16, "V": 10, "W": 22, "X": 25, "Y": 24,
    "Z": 23,
}

_TAX_CODE_EVEN_POSITION_VALUES = {
    **{str(value): value for value in range(10)},
    **{chr(ord("A") + value): value for value in range(26)},
}

_TAX_CODE_CHECK_CHARACTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def _has_valid_tax_code_check_character(tax_code: str) -> bool:
    if len(tax_code) != 16:
        return False

    try:
        total = sum(
            (
                _TAX_CODE_ODD_POSITION_VALUES[character]
                if index % 2 == 0
                else _TAX_CODE_EVEN_POSITION_VALUES[character]
            )
            for index, character in enumerate(tax_code[:15])
        )
    except KeyError:
        return False

    return tax_code[-1] == _TAX_CODE_CHECK_CHARACTERS[total % 26]


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
            "tax_code ~ "
            "'^[A-Z]{6}[0-9LMNPQRSTUV]{2}[ABCDEHLMPRST]"
            "[0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]$'",
            name="tax_code_format",
        ),
        CheckConstraint(
            "birth_date >= DATE '1900-01-01'",
            name="birth_date_min",
        ),
        CheckConstraint(
            "birth_province ~ '^[A-Z]{2}$'",
            name="birth_province_format",
        ),
        CheckConstraint(
            "residence_province ~ '^[A-Z]{2}$'",
            name="residence_province_format",
        ),
        CheckConstraint(
            "birth_province = upper(birth_province)",
            name="birth_province_uppercase",
        ),
        CheckConstraint(
            "residence_province = upper(residence_province)",
            name="residence_province_uppercase",
        ),
        CheckConstraint(
            "postal_code ~ '^[0-9]{5}$'",
            name="postal_code_format",
        ),
        CheckConstraint(
            "email ~ "
            "'^[A-Za-z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Za-z0-9-]+"
            "(\\.[A-Za-z0-9-]+)+$'",
            name="email_format",
        ),
        CheckConstraint(
            "phone ~ '^\\+?[0-9]+$'",
            name="phone_format",
        ),
        CheckConstraint(
            "length(trim(first_name)) > 0",
            name="first_name_not_blank",
        ),
        CheckConstraint(
            "length(trim(last_name)) > 0",
            name="last_name_not_blank",
        ),
        CheckConstraint(
            "length(trim(birth_city)) > 0",
            name="birth_city_not_blank",
        ),
        CheckConstraint(
            "length(trim(residence_type)) > 0",
            name="residence_type_not_blank",
        ),
        CheckConstraint(
            "length(trim(residence_address)) > 0",
            name="residence_address_not_blank",
        ),
        CheckConstraint(
            "length(trim(residence_street_number)) > 0",
            name="residence_street_number_not_blank",
        ),
        CheckConstraint(
            "length(trim(residence_city)) > 0",
            name="residence_city_not_blank",
        ),
        *no_surrounding_whitespace_constraints(
            "tax_code",
            "first_name",
            "last_name",
            "birth_city",
            "birth_province",
            "email",
            "phone",
            "residence_type",
            "residence_address",
            "residence_street_number",
            "residence_city",
            "residence_province",
            "postal_code",
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

    account: Mapped[Account | None] = relationship(
        back_populates="person",
        uselist=False,
    )

    parental_relationships: Mapped[list[ParentalResponsibility]] = relationship(
        back_populates="child",
        cascade="all, delete-orphan",
    )

    parent_profile: Mapped[Parent | None] = relationship(
        back_populates="person",
        uselist=False,
    )

    member_profile: Mapped[Member | None] = relationship(
        back_populates="person",
        uselist=False,
    )

    @validates("tax_code")
    def validate_tax_code(self, _key: str, tax_code: str) -> str:
        if not _has_valid_tax_code_check_character(tax_code):
            raise ValueError(
                "Tax code has an invalid check character"
            )

        return tax_code
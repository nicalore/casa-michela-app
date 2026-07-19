from __future__ import annotations

import string
from datetime import date
from enum import StrEnum
from typing import TYPE_CHECKING, Final

from sqlalchemy import (
    CheckConstraint,
    Date,
    String,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship, validates

from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_constraints,
    not_blank_when_present_constraints,
)
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.account import Account
    from app.models.member import Member
    from app.models.parent import Parent
    from app.models.parental_responsibility import ParentalResponsibility


class GenderEnum(StrEnum):
    M = "M"
    F = "F"


_TAX_CODE_LENGTH: Final[int] = 16

_TAX_CODE_CHECK_CHARACTERS: Final[str] = string.ascii_uppercase

_TAX_CODE_ODD_POSITION_VALUES: Final[dict[str, int]] = {
    "0": 1, "1": 0, "2": 5, "3": 7, "4": 9,
    "5": 13, "6": 15, "7": 17, "8": 19, "9": 21,
    "A": 1, "B": 0, "C": 5, "D": 7, "E": 9,
    "F": 13, "G": 15, "H": 17, "I": 19, "J": 21,
    "K": 2, "L": 4, "M": 18, "N": 20, "O": 11,
    "P": 3, "Q": 6, "R": 8, "S": 12, "T": 14,
    "U": 16, "V": 10, "W": 22, "X": 25, "Y": 24,
    "Z": 23,
}

_TAX_CODE_EVEN_POSITION_VALUES: Final[dict[str, int]] = {
    **{str(digit): digit for digit in range(10)},
    **{letter: index for index, letter in enumerate(string.ascii_uppercase)},
}

_INVALID_TAX_CODE_ERROR: Final[str] = (
    "Il codice fiscale ha un carattere di controllo non valido"
)


def _has_valid_tax_code_check_character(tax_code: str) -> bool:
    if len(tax_code) != _TAX_CODE_LENGTH:
        return False

    try:
        # Positions are 1-based in the official algorithm: even indexes here
        # are odd positions there, hence the swapped lookup tables.
        total = sum(
            (
                _TAX_CODE_ODD_POSITION_VALUES[character]
                if index % 2 == 0
                else _TAX_CODE_EVEN_POSITION_VALUES[character]
            )
            for index, character in enumerate(tax_code[:-1])
        )
    except KeyError:
        return False

    return tax_code[-1] == _TAX_CODE_CHECK_CHARACTERS[
        total % len(_TAX_CODE_CHECK_CHARACTERS)
    ]


class Person(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "people"

    __table_args__ = (
        CheckConstraint("length(tax_code) = 16", name="tax_code_length"),
        CheckConstraint("tax_code = upper(tax_code)", name="tax_code_uppercase"),
        CheckConstraint(
            "tax_code ~ "
            "'^[A-Z]{6}[0-9LMNPQRSTUV]{2}[ABCDEHLMPRST]"
            "[0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]$'",
            name="tax_code_format",
        ),
        CheckConstraint("birth_date >= DATE '1900-01-01'", name="birth_date_min"),
        CheckConstraint("birth_province ~ '^[A-Z]{2}$'", name="birth_province_format"),
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
        CheckConstraint("postal_code ~ '^[0-9]{5}$'", name="postal_code_format"),
        CheckConstraint(
            "email ~ "
            "'^[A-Za-z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Za-z0-9-]+"
            "(\\.[A-Za-z0-9-]+)+$'",
            name="email_format",
        ),
        CheckConstraint("phone ~ '^\\+?[0-9]+$'", name="phone_format"),
        CheckConstraint(
            "profile_image_url IS NULL OR profile_image_url ~ '^https?://'",
            name="profile_image_url_format",
        ),
        *not_blank_constraints(
            "first_name",
            "last_name",
            "birth_city",
            "birth_nation",
            "residence_type",
            "residence_address",
            "residence_street_number",
            "residence_city",
        ),
        *not_blank_when_present_constraints("profile_image_url"),
        *no_surrounding_whitespace_constraints(
            "tax_code",
            "first_name",
            "last_name",
            "birth_city",
            "birth_nation",
            "birth_province",
            "email",
            "phone",
            "residence_type",
            "residence_address",
            "residence_street_number",
            "residence_city",
            "residence_province",
            "postal_code",
            "profile_image_url",
        ),
    )

    tax_code: Mapped[str] = mapped_column(String(_TAX_CODE_LENGTH), primary_key=True)

    first_name: Mapped[str] = mapped_column(String(100), nullable=False)

    last_name: Mapped[str] = mapped_column(String(100), nullable=False)

    gender: Mapped[GenderEnum] = mapped_column(
        SqlEnum(GenderEnum, name="gender_enum"),
        nullable=False,
    )

    birth_date: Mapped[date] = mapped_column(Date, nullable=False)

    birth_city: Mapped[str] = mapped_column(String(100), nullable=False)

    birth_nation: Mapped[str] = mapped_column(String(100), nullable=False)

    birth_province: Mapped[str] = mapped_column(String(2), nullable=False)

    email: Mapped[str] = mapped_column(String(255), nullable=False, index=True)

    phone: Mapped[str] = mapped_column(String(20), nullable=False)

    residence_type: Mapped[str] = mapped_column(String(100), nullable=False)

    residence_address: Mapped[str] = mapped_column(String(255), nullable=False)

    residence_street_number: Mapped[str] = mapped_column(String(20), nullable=False)

    residence_city: Mapped[str] = mapped_column(String(100), nullable=False)

    residence_province: Mapped[str] = mapped_column(String(2), nullable=False)

    postal_code: Mapped[str] = mapped_column(String(5), nullable=False)

    profile_image_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)

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
            raise ValueError(_INVALID_TAX_CODE_ERROR)

        return tax_code
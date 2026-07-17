from __future__ import annotations

from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    String,
)
from sqlalchemy import (
    Enum as SqlEnum,
)
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints

if TYPE_CHECKING:
    from app.models.administrator import Administrator
    from app.models.member import Member
    from app.models.psychologist import Psychologist
    from app.models.teacher import Teacher


class CollaborationTypeEnum(StrEnum):
    VOLUNTEER = "VOLUNTEER"
    PAID = "PAID"
    PCTO = "PCTO"
    UNPAID = "UNPAID"


class Staff(Base):
    __tablename__ = "staff"

    __table_args__ = (
        CheckConstraint(
            """
            iban IS NULL
            OR length(iban) = 27
            """,
            name="iban_length",
        ),
        CheckConstraint(
            """
            iban IS NULL
            OR iban = upper(iban)
            """,
            name="iban_uppercase",
        ),
        CheckConstraint(
            """
            iban IS NULL
            OR iban ~ '^IT[0-9]{2}[A-Z][0-9]{10}[A-Z0-9]{12}$'
            """,
            name="iban_format",
        ),
        CheckConstraint(
            """
            iban IS NULL
            OR length(trim(iban)) > 0
            """,
            name="iban_not_blank",
        ),
        CheckConstraint(
            """
            collaboration_type <> 'PAID'
            OR iban IS NOT NULL
            """,
            name="paid_staff_requires_iban",
        ),
        *no_surrounding_whitespace_constraints(
            "iban",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "members.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    collaboration_type: Mapped[CollaborationTypeEnum] = mapped_column(
        SqlEnum(
            CollaborationTypeEnum,
            name="collaboration_type_enum",
        ),
        nullable=False,
    )

    iban: Mapped[str | None] = mapped_column(
        String(27),
        nullable=True,
    )

    member: Mapped[Member] = relationship(
        back_populates="staff_profile",
        uselist=False,
    )

    administrator_profile: Mapped[Administrator | None] = relationship(
        back_populates="staff_member",
        uselist=False,
    )

    psychologist_profile: Mapped[Psychologist | None] = relationship(
        back_populates="staff_member",
        uselist=False,
    )

    teacher_profile: Mapped[Teacher | None] = relationship(
        back_populates="staff_member",
        uselist=False,
    )
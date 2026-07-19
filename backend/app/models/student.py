from __future__ import annotations

from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    String,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_when_present_constraints,
)
from app.models.mixins import UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.member import Member
    from app.models.school_enrollment import SchoolEnrollment


class CertificationTypeEnum(StrEnum):
    DSA = "DSA"
    BES = "BES"
    ADHD = "ADHD"
    OTHER = "OTHER"


class Student(UpdatedAtMixin, Base):
    __tablename__ = "students"

    __table_args__ = (
        CheckConstraint(
            # IS NOT DISTINCT FROM is NULL-safe: with a plain "=", a NULL
            # certification_type would make the comparison NULL, not false,
            # and the constraint would pass.
            "certification_other_detail IS NULL "
            "OR certification_type IS NOT DISTINCT FROM 'OTHER'",
            name="certification_other_detail_requires_other_type",
        ),
        *not_blank_when_present_constraints("certification_other_detail"),
        *no_surrounding_whitespace_constraints("certification_other_detail"),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey("members.tax_code", ondelete="CASCADE"),
        primary_key=True,
    )

    authorized_early_exit: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    certification_type: Mapped[CertificationTypeEnum | None] = mapped_column(
        SqlEnum(CertificationTypeEnum, name="certification_type_enum"),
        nullable=True,
    )

    certification_other_detail: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )

    mandatory_psych_meetings_acknowledged: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    member: Mapped[Member] = relationship(
        back_populates="student_profile",
        uselist=False,
    )

    school_enrollments: Mapped[list[SchoolEnrollment]] = relationship(
        back_populates="student",
        cascade="all, delete-orphan",
    )
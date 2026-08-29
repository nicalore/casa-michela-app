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
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_when_present_constraints,
)
from app.models.mixins import UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.member import Member
    from app.models.presence import Presence
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
            "certification_other_detail IS NULL "
            "OR 'OTHER' = ANY(certification_types)",
            name="certification_other_detail_requires_other_type",
        ),
        CheckConstraint(
            "NOT ('DSA' = ANY(certification_types)) "
            "OR certification_dsa_detail IS NOT NULL",
            name="dsa_certification_says_which",
        ),
        CheckConstraint(
            "certification_dsa_detail IS NULL "
            "OR 'DSA' = ANY(certification_types)",
            name="certification_dsa_detail_requires_dsa_type",
        ),
        *not_blank_when_present_constraints(
            "certification_other_detail",
            "certification_dsa_detail",
        ),
        *no_surrounding_whitespace_constraints(
            "certification_other_detail",
            "certification_dsa_detail",
        ),
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

    certification_types: Mapped[list[CertificationTypeEnum]] = mapped_column(
        ARRAY(SqlEnum(CertificationTypeEnum, name="certification_type_enum")),
        nullable=False,
        default=list,
        server_default="{}",
    )

    certification_other_detail: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )

    certification_dsa_detail: Mapped[str | None] = mapped_column(
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

    presences: Mapped[list[Presence]] = relationship(
        back_populates="student",
        foreign_keys="[Presence.student_tax_code]",
        cascade="all, delete-orphan",
    )

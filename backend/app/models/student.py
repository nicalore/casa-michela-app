from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    String,
    func,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints

if TYPE_CHECKING:
    from app.models.member import Member
    from app.models.school_enrollment import SchoolEnrollment


class CertificationTypeEnum(StrEnum):
    DSA = "DSA"
    BES = "BES"
    ADHD = "ADHD"
    OTHER = "OTHER"


class Student(Base):
    __tablename__ = "students"

    __table_args__ = (
        CheckConstraint(
            # certification_other_detail valorizzabile solo se il tipo è OTHER;
            # IS NOT DISTINCT FROM gestisce correttamente anche il caso
            # certification_type NULL (nessuna certificazione dichiarata).
            "certification_other_detail IS NULL "
            "OR certification_type IS NOT DISTINCT FROM 'OTHER'",
            name="certification_other_detail_requires_other_type",
        ),
        CheckConstraint(
            "certification_other_detail IS NULL "
            "OR length(trim(certification_other_detail)) > 0",
            name="certification_other_detail_not_blank",
        ),
        *no_surrounding_whitespace_constraints(
            "certification_other_detail",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "members.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    authorized_early_exit: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    certification_type: Mapped[CertificationTypeEnum | None] = mapped_column(
        SqlEnum(
            CertificationTypeEnum,
            name="certification_type_enum",
        ),
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

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    member: Mapped[Member] = relationship(
        back_populates="student_profile",
        uselist=False,
    )

    school_enrollments: Mapped[list[SchoolEnrollment]] = relationship(
        back_populates="student",
        cascade="all, delete-orphan",
    )
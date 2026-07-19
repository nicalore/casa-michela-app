from __future__ import annotations

from datetime import date
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
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
    from app.models.course_participant import CourseParticipant
    from app.models.membership import Membership
    from app.models.person import Person
    from app.models.psychological_support import PsychologicalSupport
    from app.models.staff import Staff
    from app.models.student import Student


class PaymentMethodEnum(StrEnum):
    CASH = "CASH"
    BANK_TRANSFER = "BANK_TRANSFER"
    OTHER = "OTHER"


class Member(UpdatedAtMixin, Base):
    __tablename__ = "members"

    __table_args__ = (
        CheckConstraint(
            "payment_method_other IS NULL "
            "OR payment_method IS NOT DISTINCT FROM 'OTHER'",
            name="payment_method_other_requires_other_method",
        ),
        CheckConstraint(
            "emergency_contact_phone IS NULL "
            "OR emergency_contact_phone ~ '^\\+?[0-9]+$'",
            name="emergency_contact_phone_format",
        ),
        *not_blank_when_present_constraints(
            "payment_method_other",
            "emergency_contact_name",
            "allergies_notes",
            "medications_notes",
        ),
        *no_surrounding_whitespace_constraints(
            "payment_method_other",
            "emergency_contact_name",
            "emergency_contact_phone",
            "allergies_notes",
            "medications_notes",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey("people.tax_code", ondelete="CASCADE"),
        primary_key=True,
    )

    collaborating_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )

    payment_method: Mapped[PaymentMethodEnum | None] = mapped_column(
        SqlEnum(PaymentMethodEnum, name="payment_method_enum"),
        nullable=True,
    )

    payment_method_other: Mapped[str | None] = mapped_column(String(255), nullable=True)

    statute_acknowledged: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    regulation_acknowledged: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    video_surveillance_acknowledged: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    special_category_data_consent: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    newsletter_consent: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    consents_signed_at: Mapped[date | None] = mapped_column(Date, nullable=True)

    emergency_contact_name: Mapped[str | None] = mapped_column(
        String(200),
        nullable=True,
    )

    emergency_contact_phone: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )

    allergies_notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    medications_notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    person: Mapped[Person] = relationship(
        back_populates="member_profile",
        uselist=False,
    )

    memberships: Mapped[list[Membership]] = relationship(
        back_populates="member",
        cascade="all, delete-orphan",
    )

    student_profile: Mapped[Student | None] = relationship(
        back_populates="member",
        uselist=False,
    )

    course_participant_profile: Mapped[CourseParticipant | None] = relationship(
        back_populates="member",
        uselist=False,
    )

    staff_profile: Mapped[Staff | None] = relationship(
        back_populates="member",
        uselist=False,
    )

    psychological_support_profile: Mapped[PsychologicalSupport | None] = relationship(
        back_populates="member",
        uselist=False,
    )
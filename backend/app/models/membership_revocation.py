from __future__ import annotations

from datetime import date
from enum import StrEnum
from typing import TYPE_CHECKING, Final

from sqlalchemy import Boolean, CheckConstraint, Date, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core import field_lengths
from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_when_present_constraints,
)
from app.models.mixins import CreatedAtMixin

if TYPE_CHECKING:
    from app.models.membership import Membership
    from app.models.person import Person


class ExpulsionGroundEnum(StrEnum):
    BREACH = "BREACH"
    CONDUCT = "CONDUCT"
    HARM = "HARM"
    OTHER = "OTHER"


_TEXT_COLUMNS: Final[tuple[str, ...]] = (
    "reason",
    "minutes_number",
    "other_ground",
    "protocol_number",
    "card_number",
)


# What the cessation form says beyond the revoked membership itself.
class MembershipRevocation(CreatedAtMixin, Base):
    __tablename__ = "membership_revocations"

    __table_args__ = (
        CheckConstraint(
            "ground_other = (other_ground IS NOT NULL)",
            name="other_ground_with_its_box",
        ),
        CheckConstraint(
            "charged_on IS NULL OR resolution_date IS NULL "
            "OR charged_on <= resolution_date",
            name="charged_before_resolution",
        ),
        *not_blank_when_present_constraints(*_TEXT_COLUMNS),
        *no_surrounding_whitespace_constraints(*_TEXT_COLUMNS),
    )

    membership_id: Mapped[int] = mapped_column(
        ForeignKey("memberships.id", ondelete="CASCADE"),
        primary_key=True,
    )

    reason: Mapped[str | None] = mapped_column(
        String(field_lengths.REVOCATION_REASON),
        nullable=True,
    )

    resolution_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    minutes_number: Mapped[str | None] = mapped_column(
        String(field_lengths.REVOCATION_MINUTES),
        nullable=True,
    )

    ground_breach: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    ground_conduct: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    ground_harm: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    ground_other: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    other_ground: Mapped[str | None] = mapped_column(
        String(field_lengths.REVOCATION_OTHER_GROUND),
        nullable=True,
    )

    charged_on: Mapped[date | None] = mapped_column(Date, nullable=True)

    protocol_number: Mapped[str | None] = mapped_column(
        String(field_lengths.REVOCATION_PROTOCOL),
        nullable=True,
    )

    card_number: Mapped[str | None] = mapped_column(
        String(field_lengths.REVOCATION_CARD),
        nullable=True,
    )

    # The parent printed on a minor's form.
    guardian_tax_code: Mapped[str | None] = mapped_column(
        ForeignKey("people.tax_code", ondelete="SET NULL", onupdate="CASCADE"),
        nullable=True,
        index=True,
    )

    membership: Mapped[Membership] = relationship(back_populates="revocation_details")

    guardian: Mapped[Person | None] = relationship()

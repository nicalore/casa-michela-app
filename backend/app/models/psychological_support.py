from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, Date, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.member import Member


class PsychologicalSupport(Base):
    """
    Member's adhesion to the psychological counseling service.

    Intentionally minimal for now (adhesion flag + start date, no rate
    selection): full session scheduling and tariff selection will be
    added with the future calendar module.
    """

    __tablename__ = "psychological_supports"

    __table_args__ = (
        CheckConstraint(
            "start_date >= DATE '1900-01-01'",
            name="psychological_support_start_date_min",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "members.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    start_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    member: Mapped[Member] = relationship(
        back_populates="psychological_support_profile",
        uselist=False,
    )
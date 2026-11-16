from __future__ import annotations

from datetime import date
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.collaboration_type import CollaborationTypeEnum
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin


# What a staff member was from a month on, until the next row.
# No rows means Staff has always said the same.
class CompensationTerm(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "compensation_terms"

    __table_args__ = (
        UniqueConstraint(
            "staff_tax_code",
            "starts_on",
            name="unique_compensation_term_month",
        ),
        CheckConstraint(
            "EXTRACT(DAY FROM starts_on) = 1",
            name="compensation_term_starts_a_month",
        ),
        CheckConstraint(
            "gross_compensation IS NULL OR gross_compensation >= 0",
            name="compensation_term_gross_not_negative",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    staff_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("staff.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    starts_on: Mapped[date] = mapped_column(Date, nullable=False)

    collaboration_type: Mapped[CollaborationTypeEnum] = mapped_column(
        SqlEnum(CollaborationTypeEnum, name="collaboration_type_enum"),
        nullable=False,
    )

    gross_compensation: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 2),
        nullable=True,
    )

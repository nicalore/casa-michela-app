from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    String,
)
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints

if TYPE_CHECKING:
    from app.models.parent import Parent
    from app.models.person import Person


class ParentalResponsibility(Base):
    __tablename__ = "parental_responsibilities"

    __table_args__ = (
        CheckConstraint(
            "parent_tax_code <> child_tax_code",
            name="parent_child_different",
        ),
        CheckConstraint(
            """
            pickup_restriction_reason IS NULL
            OR length(trim(pickup_restriction_reason)) > 0
            """,
            name="pickup_restriction_reason_not_blank",
        ),
        CheckConstraint(
            "authorized_pickup = false OR pickup_restriction_reason IS NULL",
            name="pickup_restriction_reason_requires_not_authorized",
        ),
        *no_surrounding_whitespace_constraints(
            "pickup_restriction_reason",
        ),
    )

    parent_tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "parents.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    child_tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "people.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    authorized_pickup: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )

    pickup_restriction_reason: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
    )

    parent: Mapped[Parent] = relationship(
        back_populates="children_relationships",
    )

    child: Mapped[Person] = relationship(
        back_populates="parental_relationships",
    )
from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
)
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.db.base import Base

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

    parent: Mapped[Parent] = relationship(
        back_populates="children_relationships",
    )

    child: Mapped[Person] = relationship(
        back_populates="parental_relationships",
    )
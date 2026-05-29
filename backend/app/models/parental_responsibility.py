from __future__ import annotations

from sqlalchemy import ForeignKey

from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from app.db.base import Base


class ParentalResponsibility(Base):
    __tablename__ = "parental_responsibilities"

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

    parent: Mapped["Parent"] = relationship(
        back_populates="children_relationships",
    )

    child: Mapped["Person"] = relationship(
        back_populates="parental_relationships",
    )
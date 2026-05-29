from __future__ import annotations

from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Parent(Base):
    __tablename__ = "parents"

    tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "people.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    person: Mapped["Person"] = relationship(
        back_populates="parent_profile",
        uselist=False,
    )

    children_relationships: Mapped[list["ParentalResponsibility"]] = relationship(
        back_populates="parent",
        cascade="all, delete-orphan",
    )
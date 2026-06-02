from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.parental_responsibility import ParentalResponsibility
    from app.models.person import Person


class Parent(Base):
    """
    Parent profile.

    A Parent is a Person that can hold parental
    responsibilities over one or more members.
    """

    __tablename__ = "parents"

    tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "people.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    person: Mapped[Person] = relationship(
        back_populates="parent_profile",
        uselist=False,
    )

    children_relationships: Mapped[list[ParentalResponsibility]] = relationship(
        back_populates="parent",
        cascade="all, delete-orphan",
    )
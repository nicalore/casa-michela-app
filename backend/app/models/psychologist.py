from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.staff import Staff


class Psychologist(Base):
    __tablename__ = "psychologists"

    tax_code: Mapped[str] = mapped_column(
        ForeignKey("staff.tax_code", ondelete="CASCADE"),
        primary_key=True,
    )

    staff_member: Mapped[Staff] = relationship(
        back_populates="psychologist_profile",
        uselist=False,
    )
from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.service import Service
    from app.models.teacher import Teacher


# A service a teacher can take on: the twin of TeachingCompetence, minus the
# study programme. A discipline is taught differently to a first year and to a
# fifth, whereas a service is the same help whoever asks for it, so the key is
# just the teacher and the service.
class TeacherService(Base):
    __tablename__ = "teacher_services"

    teacher_tax_code: Mapped[str] = mapped_column(
        ForeignKey("teachers.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    service_name: Mapped[str] = mapped_column(
        # A service is keyed by its name, which can be renamed: onupdate keeps
        # the teachers who offer it attached across a rename.
        ForeignKey("services.name", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
        index=True,
    )

    teacher: Mapped[Teacher] = relationship(back_populates="teacher_services")

    service: Mapped[Service] = relationship(back_populates="teacher_services")

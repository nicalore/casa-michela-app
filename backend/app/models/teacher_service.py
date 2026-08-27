from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.service import Service
    from app.models.teacher import Teacher


# Twin of TeachingCompetence minus the study programme: a service is the same
# help whoever asks, so the key is just (teacher, service).
class TeacherService(Base):
    __tablename__ = "teacher_services"

    teacher_tax_code: Mapped[str] = mapped_column(
        ForeignKey("teachers.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    service_name: Mapped[str] = mapped_column(
        # Services are keyed by a renameable name: onupdate keeps rows attached.
        ForeignKey("services.name", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
        index=True,
    )

    teacher: Mapped[Teacher] = relationship(back_populates="teacher_services")

    service: Mapped[Service] = relationship(back_populates="teacher_services")

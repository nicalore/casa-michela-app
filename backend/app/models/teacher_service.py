from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, Date, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.booking_window import today_in_rome
from app.db.base import Base

if TYPE_CHECKING:
    from app.models.service import Service
    from app.models.teacher import Teacher


# Twin of TeachingCompetence without the programme: key is (teacher, service, dates).
class TeacherService(Base):
    __tablename__ = "teacher_services"

    __table_args__ = (
        CheckConstraint(
            "valid_to IS NULL OR valid_to > valid_from",
            name="validity_ends_after_start",
        ),
        Index(
            "ux_teacher_service_open",
            "teacher_tax_code",
            "service_name",
            unique=True,
            postgresql_where=text("valid_to IS NULL"),
        ),
    )

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

    valid_from: Mapped[date] = mapped_column(
        Date,
        primary_key=True,
        default=today_in_rome,
    )

    valid_to: Mapped[date | None] = mapped_column(Date, nullable=True)

    teacher: Mapped[Teacher] = relationship()

    service: Mapped[Service] = relationship()

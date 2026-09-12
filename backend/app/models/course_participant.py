from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.course import Course
    from app.models.member import Member


class CourseParticipant(Base):
    __tablename__ = "course_participants"

    __table_args__ = (
        CheckConstraint(
            "medical_certificate_expiration > DATE '1900-01-01'",
            name="medical_certificate_expiration_min",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey("members.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    # A course may be joined before the certificate is handed in.
    medical_certificate_expiration: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )

    # Renaming a course rewrites this value; deleting one that is still in use
    # is refused by the database.
    course_type: Mapped[str] = mapped_column(
        String(255),
        ForeignKey("courses.name", onupdate="CASCADE", ondelete="RESTRICT"),
        nullable=False,
    )

    course: Mapped[Course] = relationship(back_populates="participants")

    member: Mapped[Member] = relationship(
        back_populates="course_participant_profile",
        uselist=False,
    )

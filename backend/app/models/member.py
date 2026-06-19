from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    ForeignKey,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.course_participant import CourseParticipant
    from app.models.membership import Membership
    from app.models.person import Person
    from app.models.staff import Staff
    from app.models.student import Student


class Member(Base):
    __tablename__ = "members"

    tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "people.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    collaborating_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )

    person: Mapped[Person] = relationship(
        back_populates="member_profile",
        uselist=False,
    )

    memberships: Mapped[list[Membership]] = relationship(
        back_populates="member",
        cascade="all, delete-orphan",
    )

    student_profile: Mapped[Student | None] = relationship(
        back_populates="member",
        uselist=False,
    )

    course_participant_profile: Mapped[CourseParticipant | None] = relationship(
        back_populates="member",
        uselist=False,
    )

    staff_profile: Mapped[Staff | None] = relationship(
        back_populates="member",
        uselist=False,
    )
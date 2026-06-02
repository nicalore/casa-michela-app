from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import no_surrounding_whitespace_constraints

if TYPE_CHECKING:
    from app.models.course_partecipant import CoursePartecipant
    from app.models.membership import Membership
    from app.models.person import Person
    from app.models.staff import Staff
    from app.models.student import Student


class Member(Base):
    __tablename__ = "members"

    __table_args__ = (
        CheckConstraint(
            """
            profile_image_url IS NULL
            OR length(trim(profile_image_url)) > 0
            """,
            name="profile_image_url_not_blank",
        ),
        CheckConstraint(
            """
            profile_image_url IS NULL
            OR profile_image_url ~ '^https?://'
            """,
            name="profile_image_url_format",
        ),
        *no_surrounding_whitespace_constraints(
            "profile_image_url",
        ),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "people.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    profile_image_url: Mapped[str | None] = mapped_column(
        String(2048),
        nullable=True,
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

    course_partecipant_profile: Mapped[CoursePartecipant | None] = relationship(
        back_populates="member",
        uselist=False,
    )

    staff_profile: Mapped[Staff | None] = relationship(
        back_populates="member",
        uselist=False,
    )
from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import Boolean, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.member import Member
    from app.models.school_enrollment import SchoolEnrollment


class Student(Base):
    __tablename__ = "students"

    tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "members.tax_code",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    authorized_early_exit: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    member: Mapped[Member] = relationship(
        back_populates="student_profile",
        uselist=False,
    )

    school_enrollments: Mapped[list[SchoolEnrollment]] = relationship(
        back_populates="student",
        cascade="all, delete-orphan",
    )
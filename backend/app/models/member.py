from __future__ import annotations

from sqlalchemy import Boolean, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Member(Base):
    __tablename__ = "members"

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

    person: Mapped["Person"] = relationship(
        back_populates="member_profile",
        uselist=False,
    )

    memberships: Mapped[list["Membership"]] = relationship(
    back_populates="member",
    cascade="all, delete-orphan",
    )
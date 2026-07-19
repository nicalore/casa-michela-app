from __future__ import annotations

from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Index,
    String,
    text,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.constraints import (
    no_surrounding_whitespace_constraints,
    not_blank_when_present_constraints,
)

if TYPE_CHECKING:
    from app.models.staff import Staff


class AdministratorRoleEnum(StrEnum):
    PRESIDENT = "PRESIDENT"
    VICE_PRESIDENT = "VICE_PRESIDENT"
    TREASURER = "TREASURER"
    OTHER = "OTHER"


class Administrator(Base):
    __tablename__ = "administrators"

    __table_args__ = (
        CheckConstraint(
            "(role = 'OTHER' AND other_role IS NOT NULL) "
            "OR (role <> 'OTHER' AND other_role IS NULL)",
            name="other_role_consistency",
        ),
        Index(
            "uq_administrator_president",
            "role",
            unique=True,
            postgresql_where=text("role = 'PRESIDENT'"),
        ),
        Index(
            "uq_administrator_vice_president",
            "role",
            unique=True,
            postgresql_where=text("role = 'VICE_PRESIDENT'"),
        ),
        Index(
            "uq_administrator_treasurer",
            "role",
            unique=True,
            postgresql_where=text("role = 'TREASURER'"),
        ),
        *not_blank_when_present_constraints("other_role"),
        *no_surrounding_whitespace_constraints("other_role"),
    )

    tax_code: Mapped[str] = mapped_column(
        ForeignKey("staff.tax_code", ondelete="CASCADE"),
        primary_key=True,
    )

    role: Mapped[AdministratorRoleEnum] = mapped_column(
        SqlEnum(AdministratorRoleEnum, name="administrator_role_enum"),
        nullable=False,
    )

    other_role: Mapped[str | None] = mapped_column(String(100), nullable=True)

    staff_member: Mapped[Staff] = relationship(
        back_populates="administrator_profile",
        uselist=False,
    )
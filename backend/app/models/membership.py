from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    UniqueConstraint,
    event,
    func,
)
from sqlalchemy import (
    Enum as SqlEnum,
)
from sqlalchemy.orm import (
    Mapped,
    Session,
    mapped_column,
    relationship,
)

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.member import Member


class MembershipRevocationEnum(StrEnum):
    NO = "NO"
    EXPULSION = "EXPULSION"
    RESIGNATION = "RESIGNATION"


class Membership(Base):
    __tablename__ = "memberships"

    __table_args__ = (
        UniqueConstraint(
            "member_tax_code",
            "year",
            name="uq_membership_member_year",
        ),
        CheckConstraint(
            "year >= 1900",
            name="membership_year_min",
        ),
        CheckConstraint(
            "start_date >= DATE '1900-01-01'",
            name="membership_start_date_min",
        ),
        CheckConstraint(
            "end_date > start_date",
            name="membership_end_after_start",
        ),
        CheckConstraint(
            """
            (
                revocation = 'NO'
                AND renewal_period_days > 0
            )
            OR
            (
                revocation IN ('EXPULSION', 'RESIGNATION')
                AND renewal_period_days = 0
            )
            """,
            name="membership_renewal_period_consistency",
        ),
    )

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    member_tax_code: Mapped[str] = mapped_column(
        ForeignKey(
            "members.tax_code",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    revocation: Mapped[MembershipRevocationEnum] = mapped_column(
        SqlEnum(
            MembershipRevocationEnum,
            name="membership_revocation_enum",
        ),
        nullable=False,
        default=MembershipRevocationEnum.NO,
        server_default="NO",
    )

    year: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    start_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    end_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    renewal_period_days: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    member: Mapped[Member] = relationship(
        back_populates="memberships",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


@event.listens_for(Session, "before_flush")
def _validate_memberships(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    current_year = date.today().year

    for obj in session.new.union(session.dirty):
        if not isinstance(obj, Membership):
            continue

        if obj.year > current_year:
            raise ValueError(
                "Membership year cannot be in the future"
            )
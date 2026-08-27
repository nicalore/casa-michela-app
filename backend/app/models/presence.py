from __future__ import annotations

from datetime import date, time
from typing import TYPE_CHECKING, Final

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    Integer,
    String,
    Time,
    event,
    select,
)
from sqlalchemy.orm import Mapped, Session, mapped_column, relationship

from app.db.base import Base
from app.models.flush_state import pending_instances
from app.models.mixins import CreatedAtMixin, UpdatedAtMixin

if TYPE_CHECKING:
    from app.models.booking import Booking
    from app.models.person import Person
    from app.models.student import Student

_BOOKER_MUST_BE_STUDENT_ERROR: Final[str] = (
    "Lo studente non ha genitori associati: il prenotante deve essere lo "
    "studente stesso"
)

_BOOKER_MUST_BE_A_PARENT_OF_STUDENT_ERROR: Final[str] = (
    "Il prenotante deve essere uno dei genitori associati allo studente"
)


class Presence(CreatedAtMixin, UpdatedAtMixin, Base):
    __tablename__ = "presences"

    __table_args__ = (
        CheckConstraint("id > 0", name="positive_presence_id"),
        CheckConstraint("end_time > start_time", name="presence_end_after_start"),
        # Thirty minutes is the shortest teachable stretch. Subsumes the
        # check above, which stays for its distinct error message.
        CheckConstraint(
            "end_time - start_time >= INTERVAL '30 minutes'",
            name="presence_minimum_duration",
        ),
        CheckConstraint(
            "mode IN ('presence', 'online')",
            name="presence_mode_valid",
        ),
        CheckConstraint(
            "EXTRACT(MINUTE FROM start_time)::integer % 15 = 0 "
            "AND EXTRACT(MINUTE FROM end_time)::integer % 15 = 0",
            name="presence_time_step",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    date: Mapped[date] = mapped_column(Date, nullable=False)

    # Same two modes the opening hours are kept in.
    mode: Mapped[str] = mapped_column(String(20), nullable=False)

    start_time: Mapped[time] = mapped_column(Time, nullable=False)

    end_time: Mapped[time] = mapped_column(Time, nullable=False)

    student_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("students.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    booker_tax_code: Mapped[str] = mapped_column(
        ForeignKey("people.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    student: Mapped[Student] = relationship(
        back_populates="presences",
        foreign_keys=[student_tax_code],
    )

    booker: Mapped[Person] = relationship(
        back_populates="presences_booked",
        foreign_keys=[booker_tax_code],
    )

    bookings: Mapped[list[Booking]] = relationship(
        back_populates="presence",
        cascade="all, delete-orphan",
    )


@event.listens_for(Session, "before_flush")
def _validate_presence_booker(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.models.administrator import Administrator
    from app.models.parental_responsibility import ParentalResponsibility

    for presence in pending_instances(session, Presence):
        parent_tax_codes = session.scalars(
            select(ParentalResponsibility.parent_tax_code).where(
                ParentalResponsibility.child_tax_code == presence.student_tax_code,
            ),
        ).all()

        if presence.booker_tax_code in parent_tax_codes:
            continue

        if (
            not parent_tax_codes
            and presence.booker_tax_code == presence.student_tax_code
        ):
            continue

        # An administrator may book on a student's behalf; records who entered it.
        is_admin_booker = (
            session.scalar(
                select(Administrator.tax_code).where(
                    Administrator.tax_code == presence.booker_tax_code,
                ),
            )
            is not None
        )

        if is_admin_booker:
            continue

        if not parent_tax_codes:
            raise ValueError(_BOOKER_MUST_BE_STUDENT_ERROR)

        raise ValueError(_BOOKER_MUST_BE_A_PARENT_OF_STUDENT_ERROR)

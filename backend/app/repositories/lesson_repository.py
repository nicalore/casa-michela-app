from __future__ import annotations

from collections.abc import Collection, Sequence
from dataclasses import dataclass
from datetime import date, time

from sqlalchemy import Select, or_, select
from sqlalchemy.orm import selectinload

from app.models.availability import Availability
from app.models.booking import Booking
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.lesson_discipline import LessonDiscipline
from app.models.presence import Presence
from app.repositories.base import WritableRepository
from app.repositories.booking_repository import BOOKING_EAGER_LOADER

_EAGER_LOADER = (
    selectinload(Lesson.availability),
    selectinload(Lesson.lesson_bookings)
    .selectinload(LessonBooking.booking)
    .options(*BOOKING_EAGER_LOADER),
    selectinload(Lesson.lesson_disciplines).selectinload(
        LessonDiscipline.association_subject,
    ),
)


# Who is allowed to see a lesson, as a set of alternatives rather than a switch
# on one role: an account can be a parent and a teacher at once, and it should
# see both its own hours and its children's. Every branch that is None is simply
# not asked about; an administrator asks about none of them.
@dataclass(frozen=True)
class LessonVisibility:
    teacher_tax_code: str | None = None
    student_tax_codes: frozenset[str] = frozenset()
    booker_tax_code: str | None = None
    published_only: bool = False

    @property
    def is_unrestricted(self) -> bool:
        return (
            self.teacher_tax_code is None
            and not self.student_tax_codes
            and self.booker_tax_code is None
            and not self.published_only
        )


class LessonRepository(WritableRepository[Lesson]):
    def _visible(
        self,
        stmt: Select[tuple[Lesson]],
        visibility: LessonVisibility,
    ) -> Select[tuple[Lesson]]:
        if visibility.is_unrestricted:
            return stmt

        if visibility.published_only:
            stmt = stmt.where(
                select(CalendarPublication.date)
                .where(
                    CalendarPublication.date == Lesson.date,
                    CalendarPublication.band == Lesson.band,
                )
                .exists(),
            )

        branches = []

        if visibility.teacher_tax_code is not None:
            branches.append(
                select(Availability.id)
                .where(
                    Availability.id == Lesson.availability_id,
                    Availability.teacher_tax_code == visibility.teacher_tax_code,
                )
                .exists(),
            )

        # The pupil taught and whoever entered the request are two different
        # people whenever a parent books: both have to be able to see the hour.
        pupil_branch = []

        if visibility.student_tax_codes:
            pupil_branch.append(
                Presence.student_tax_code.in_(visibility.student_tax_codes),
            )

        if visibility.booker_tax_code is not None:
            pupil_branch.append(
                Presence.booker_tax_code == visibility.booker_tax_code,
            )

        if pupil_branch:
            branches.append(
                select(LessonBooking.lesson_id)
                .join(Booking, Booking.id == LessonBooking.booking_id)
                .join(Presence, Presence.id == Booking.presence_id)
                .where(LessonBooking.lesson_id == Lesson.id, or_(*pupil_branch))
                .exists(),
            )

        if branches:
            stmt = stmt.where(or_(*branches))

        return stmt

    async def list(
        self,
        *,
        visibility: LessonVisibility,
        date_from: date | None = None,
        date_to: date | None = None,
        band: str | None = None,
        mode: str | None = None,
        teacher_tax_code: str | None = None,
    ) -> Sequence[Lesson]:
        stmt = (
            select(Lesson)
            .options(*_EAGER_LOADER)
            .order_by(Lesson.date, Lesson.start_time, Lesson.id)
        )

        if date_from is not None:
            stmt = stmt.where(Lesson.date >= date_from)

        if date_to is not None:
            stmt = stmt.where(Lesson.date <= date_to)

        if band is not None:
            stmt = stmt.where(Lesson.band == band)

        if mode is not None:
            stmt = stmt.where(Lesson.mode == mode)

        if teacher_tax_code is not None:
            stmt = stmt.where(
                select(Availability.id)
                .where(
                    Availability.id == Lesson.availability_id,
                    Availability.teacher_tax_code == teacher_tax_code,
                )
                .exists(),
            )

        return (
            (await self.session.execute(self._visible(stmt, visibility)))
            .scalars()
            .all()
        )

    async def get_by_id(
        self,
        lesson_id: int,
        *,
        visibility: LessonVisibility,
    ) -> Lesson | None:
        stmt = select(Lesson).options(*_EAGER_LOADER).where(Lesson.id == lesson_id)

        return await self.session.scalar(self._visible(stmt, visibility))

    # A teacher cannot be in two places at once, and here that is meant across
    # modes as well: availabilities may overlap between being in the building and
    # being online, lessons may not.
    async def find_teacher_overlap(
        self,
        *,
        teacher_tax_code: str,
        day: date,
        start_time: time,
        end_time: time,
        exclude_id: int | None = None,
    ) -> Lesson | None:
        stmt = (
            select(Lesson)
            .join(Availability, Availability.id == Lesson.availability_id)
            .where(
                Availability.teacher_tax_code == teacher_tax_code,
                Lesson.date == day,
                Lesson.start_time < end_time,
                Lesson.end_time > start_time,
            )
        )

        if exclude_id is not None:
            stmt = stmt.where(Lesson.id != exclude_id)

        return await self.session.scalar(stmt)

    # Same rule from the other side of the room.
    async def find_student_overlap(
        self,
        *,
        student_tax_codes: Collection[str],
        day: date,
        start_time: time,
        end_time: time,
        exclude_id: int | None = None,
    ) -> str | None:
        if not student_tax_codes:
            return None

        stmt = (
            select(Presence.student_tax_code)
            .join(Booking, Booking.presence_id == Presence.id)
            .join(LessonBooking, LessonBooking.booking_id == Booking.id)
            .join(Lesson, Lesson.id == LessonBooking.lesson_id)
            .where(
                Presence.student_tax_code.in_(student_tax_codes),
                Lesson.date == day,
                Lesson.start_time < end_time,
                Lesson.end_time > start_time,
            )
        )

        if exclude_id is not None:
            stmt = stmt.where(Lesson.id != exclude_id)

        return await self.session.scalar(stmt)

    async def list_for_band(self, day: date, band: str) -> Sequence[Lesson]:
        stmt = (
            select(Lesson)
            .options(*_EAGER_LOADER)
            .where(Lesson.date == day, Lesson.band == band)
            .order_by(Lesson.start_time, Lesson.id)
        )

        return (await self.session.execute(stmt)).scalars().all()

    # Eagerly loaded like the band listing: the callers walk from a lesson to
    # its teacher and to the pupils in it, counting heads in a room, and every
    # one of those steps would otherwise be a lazy load under async.
    async def list_for_day(self, day: date) -> Sequence[Lesson]:
        stmt = (
            select(Lesson)
            .options(*_EAGER_LOADER)
            .where(Lesson.date == day)
            .order_by(Lesson.start_time, Lesson.id)
        )

        return (await self.session.execute(stmt)).scalars().all()

    async def find_for_availability(
        self,
        availability_id: int,
    ) -> Sequence[Lesson]:
        stmt = (
            select(Lesson)
            .where(Lesson.availability_id == availability_id)
            .order_by(Lesson.start_time)
        )

        return (await self.session.execute(stmt)).scalars().all()

    async def find_scheduled_booking_ids(
        self,
        booking_ids: Collection[int],
    ) -> set[int]:
        if not booking_ids:
            return set()

        rows = await self.session.scalars(
            select(LessonBooking.booking_id).where(
                LessonBooking.booking_id.in_(booking_ids),
            ),
        )

        return set(rows)

    # Which of a presence's bookings are already in a lesson, for the guards
    # that refuse to let a scheduled request be edited out from under one.
    async def find_scheduled_booking_ids_for_presence(
        self,
        presence_id: int,
    ) -> set[int]:
        rows = await self.session.scalars(
            select(LessonBooking.booking_id)
            .join(Booking, Booking.id == LessonBooking.booking_id)
            .where(Booking.presence_id == presence_id),
        )

        return set(rows)

    # Everything already scheduled against these bookings, for the coverage
    # check: how many minutes and which disciplines each request has been given.
    async def list_links_for_bookings(
        self,
        booking_ids: Collection[int],
    ) -> Sequence[tuple[int, int, time, time]]:
        if not booking_ids:
            return []

        stmt = (
            select(
                LessonBooking.booking_id,
                Lesson.id,
                Lesson.start_time,
                Lesson.end_time,
            )
            .join(Lesson, Lesson.id == LessonBooking.lesson_id)
            .where(LessonBooking.booking_id.in_(booking_ids))
        )

        return (await self.session.execute(stmt)).all()

    async def list_disciplines_for_lessons(
        self,
        lesson_ids: Collection[int],
    ) -> Sequence[tuple[int, int]]:
        if not lesson_ids:
            return []

        stmt = select(
            LessonDiscipline.lesson_id,
            LessonDiscipline.association_subject_id,
        ).where(LessonDiscipline.lesson_id.in_(lesson_ids))

        return (await self.session.execute(stmt)).all()

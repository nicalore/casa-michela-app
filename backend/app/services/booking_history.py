from collections import defaultdict
from datetime import date, time, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.time_band import band_of
from app.models.association_subject import AssociationSubject
from app.models.availability import Availability
from app.models.booking import Booking
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.ministry_subject import MinistrySubject
from app.models.person import Person
from app.models.presence import Presence
from app.models.subject_requested import SubjectRequested
from app.schemas.booking_history import (
    BookingHistoryBookingResponse,
    BookingHistoryDayResponse,
    BookingHistoryLessonResponse,
    BookingHistoryMonthResponse,
    BookingHistoryPersonResponse,
    BookingHistoryStretchResponse,
    BookingKind,
)
from app.services.worked_hours import month_after, published_pairs

_ONLINE = "online"


def _sorted_names(names: set[str]) -> list[str]:
    return sorted(names, key=str.casefold)


async def _people(
    db: AsyncSession,
    codes: set[str],
) -> dict[str, BookingHistoryPersonResponse]:
    if not codes:
        return {}

    rows = await db.execute(
        select(Person.tax_code, Person.first_name, Person.last_name).where(
            Person.tax_code.in_(codes),
        ),
    )

    return {
        row.tax_code: BookingHistoryPersonResponse(
            tax_code=row.tax_code,
            first_name=row.first_name,
            last_name=row.last_name,
        )
        for row in rows
    }


# Subject requests by booking: the subjects' names and their disciplines' names.
async def _requests(
    db: AsyncSession,
    booking_ids: list[int],
) -> dict[int, tuple[set[str], set[str]]]:
    rows = await db.execute(
        select(
            SubjectRequested.booking_id,
            MinistrySubject.name.label("subject"),
            AssociationSubject.name.label("discipline"),
        )
        .join(
            MinistrySubject,
            MinistrySubject.id == SubjectRequested.ministry_subject_id,
        )
        .join(
            AssociationSubject,
            AssociationSubject.id == SubjectRequested.association_subject_id,
        )
        .where(SubjectRequested.booking_id.in_(booking_ids)),
    )
    found: dict[int, tuple[set[str], set[str]]] = defaultdict(lambda: (set(), set()))

    for row in rows:
        subjects, disciplines = found[row.booking_id]
        subjects.add(row.subject)
        disciplines.add(row.discipline)

    return found


async def _lessons(
    db: AsyncSession,
    booking_ids: list[int],
) -> dict[int, list[tuple[int, str, time, time]]]:
    rows = await db.execute(
        select(
            LessonBooking.booking_id,
            Lesson.id,
            Availability.teacher_tax_code,
            Lesson.start_time,
            Lesson.end_time,
        )
        .join(Lesson, Lesson.id == LessonBooking.lesson_id)
        .join(Availability, Availability.id == Lesson.availability_id)
        .where(LessonBooking.booking_id.in_(booking_ids))
        .order_by(Lesson.start_time, Lesson.id),
    )
    found: dict[int, list[tuple[int, str, time, time]]] = defaultdict(list)

    for row in rows:
        found[row.booking_id].append(
            (row.id, row.teacher_tax_code, row.start_time, row.end_time),
        )

    return found


def _naming(
    booking: Booking,
    association_name: str | None,
    requests: tuple[set[str], set[str]] | None,
) -> tuple[BookingKind, str, str | None]:
    if booking.service_name is not None:
        return "SERVICE", booking.service_name, None

    if association_name is not None:
        return "DISCIPLINE", association_name, None

    subjects, disciplines = requests or (set(), set())
    name = ", ".join(_sorted_names(disciplines)) or ", ".join(_sorted_names(subjects))
    subject = ", ".join(_sorted_names(subjects)) or None

    return "SUBJECT", name, None if subject == name else subject


# A pupil's bookings in a month, up to today: what was asked and who taught it.
async def month_history(
    db: AsyncSession,
    student_tax_code: str,
    first: date,
    today: date,
) -> BookingHistoryMonthResponse:
    end = min(month_after(first), today + timedelta(days=1))

    presences = (
        await db.scalars(
            select(Presence)
            .where(
                Presence.student_tax_code == student_tax_code,
                Presence.date >= first,
                Presence.date < end,
            )
            .order_by(Presence.date, Presence.start_time, Presence.id),
        )
    ).all()

    presence_ids = [presence.id for presence in presences]
    booking_rows = (
        await db.execute(
            select(Booking, AssociationSubject.name)
            .outerjoin(
                AssociationSubject,
                AssociationSubject.id == Booking.association_subject_id,
            )
            .where(Booking.presence_id.in_(presence_ids))
            .order_by(Booking.id),
        )
    ).tuples().all() if presence_ids else []

    booking_ids = [booking.id for booking, _ in booking_rows]
    requests = await _requests(db, booking_ids) if booking_ids else {}
    lessons = await _lessons(db, booking_ids) if booking_ids else {}
    published = await published_pairs(db, first, end)

    codes = {presence.booker_tax_code for presence in presences}
    codes |= {
        teacher for found in lessons.values() for _, teacher, _, _ in found
    }
    people = await _people(db, codes)

    by_presence: dict[int, list[BookingHistoryBookingResponse]] = defaultdict(list)
    minutes = {"presence": 0, _ONLINE: 0}
    modes = {presence.id: presence.mode for presence in presences}
    bands = {presence.id: band_of(presence.start_time).value for presence in presences}
    days_of = {presence.id: presence.date for presence in presences}

    for booking, association_name in booking_rows:
        kind, name, subject = _naming(
            booking,
            association_name,
            requests.get(booking.id),
        )
        is_published = (
            days_of[booking.presence_id],
            bands[booking.presence_id],
        ) in published
        taught = lessons.get(booking.id, []) if is_published else []

        by_presence[booking.presence_id].append(
            BookingHistoryBookingResponse(
                id=booking.id,
                kind=kind,
                name=name,
                subject=subject,
                duration=booking.duration,
                tags=[str(tag) for tag in booking.tags],
                topic=booking.topic,
                published=is_published,
                lessons=[
                    BookingHistoryLessonResponse(
                        id=lesson_id,
                        teacher=people[teacher],
                        start_time=start,
                        end_time=finish,
                    )
                    for lesson_id, teacher, start, finish in taught
                ],
            ),
        )
        minutes[modes[booking.presence_id]] += booking.duration

    stretches: dict[date, list[BookingHistoryStretchResponse]] = defaultdict(list)

    for presence in presences:
        stretches[presence.date].append(
            BookingHistoryStretchResponse(
                id=presence.id,
                mode="online" if presence.mode == _ONLINE else "presence",
                band=bands[presence.id],
                start_time=presence.start_time,
                end_time=presence.end_time,
                booker=people[presence.booker_tax_code],
                booked_at=presence.created_at,
                bookings=by_presence.get(presence.id, []),
            ),
        )

    return BookingHistoryMonthResponse(
        booked_days=len(stretches),
        booked_minutes=minutes["presence"] + minutes[_ONLINE],
        presence_minutes=minutes["presence"],
        online_minutes=minutes[_ONLINE],
        days=[
            BookingHistoryDayResponse(date=day, stretches=found)
            for day, found in stretches.items()
        ],
    )


# First days of the months with something booked, up to today.
async def booked_months(
    db: AsyncSession,
    student_tax_code: str,
    today: date,
) -> list[date]:
    days = await db.scalars(
        select(Presence.date)
        .where(
            Presence.student_tax_code == student_tax_code,
            Presence.date <= today,
        )
        .distinct(),
    )

    return sorted({day.replace(day=1) for day in days})

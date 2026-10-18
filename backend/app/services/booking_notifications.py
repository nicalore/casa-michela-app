from collections import defaultdict
from collections.abc import Iterable, Mapping
from datetime import date
from typing import Final

from sqlalchemy import ColumnElement, and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account
from app.models.booking import Booking
from app.models.booking_preferred_teacher import BookingPreferredTeacher
from app.models.notification import NotificationKindEnum
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import Person
from app.models.presence import Presence
from app.models.subject_requested import SubjectRequested
from app.repositories.identity_repository import IdentityRepository
from app.services import change_notices
from app.services.change_notices import Days, Item, Scene, Texts, Topic
from app.services.notifications import is_reachable
from app.services.push import PushBatch, joined
from app.services.role_service import RoleService

# A lesson as its pupil and parents see it.
Lesson = Item

_BOOKINGS: Final[Topic] = Topic(
    added=NotificationKindEnum.BOOKING_ADDED,
    changed=NotificationKindEnum.BOOKING_CHANGED,
    cancelled=NotificationKindEnum.BOOKING_CANCELLED,
    texts={
        NotificationKindEnum.BOOKING_ADDED: Texts(
            one="{author} ha prenotato una nuova lezione",
            many="{author} ha prenotato nuove lezioni",
            body_one="Tocca per visualizzarla",
            web_body_one="Clicca per visualizzarla",
            body_many="Tocca per visualizzarle",
            web_body_many="Clicca per visualizzarle",
        ),
        NotificationKindEnum.BOOKING_CANCELLED: Texts(
            one="{author} ha cancellato una lezione",
            many="{author} ha cancellato alcune lezioni",
            body_one="Tocca per visualizzare le prenotazioni",
            web_body_one="Clicca per visualizzare le prenotazioni",
            body_many="Tocca per visualizzare le prenotazioni",
            web_body_many="Clicca per visualizzare le prenotazioni",
        ),
        NotificationKindEnum.BOOKING_CHANGED: Texts(
            one="{author} ha modificato una lezione",
            many="{author} ha modificato alcune lezioni",
            body_one="Tocca per visualizzare le prenotazioni",
            web_body_one="Clicca per visualizzare le prenotazioni",
            body_many="Tocca per visualizzare le prenotazioni",
            web_body_many="Clicca per visualizzare le prenotazioni",
        ),
    },
)


# The lessons matching, each as a reader sees it, with the pupil they belong to.
async def _read(
    db: AsyncSession,
    criterion: ColumnElement[bool],
) -> tuple[str | None, dict[int, Item]]:
    rows = (
        await db.execute(
            select(
                Booking.id,
                Presence.student_tax_code,
                Presence.date,
                Presence.mode,
                Presence.start_time,
                Presence.end_time,
                Booking.duration,
                Booking.association_subject_id,
                Booking.service_name,
                Booking.tags,
                Booking.topic,
                Booking.notes,
            )
            .join(Presence, Booking.presence_id == Presence.id)
            .where(criterion)
        )
    ).all()
    ids = [row.id for row in rows]
    teachers: dict[int, set[str]] = defaultdict(set)
    subjects: dict[int, set[int]] = defaultdict(set)

    if ids:
        for booking_id, teacher in await db.execute(
            select(
                BookingPreferredTeacher.booking_id,
                BookingPreferredTeacher.teacher_tax_code,
            ).where(BookingPreferredTeacher.booking_id.in_(ids))
        ):
            teachers[booking_id].add(teacher)

        for booking_id, subject in await db.execute(
            select(
                SubjectRequested.booking_id,
                SubjectRequested.ministry_subject_id,
            ).where(SubjectRequested.booking_id.in_(ids))
        ):
            subjects[booking_id].add(subject)

    lessons = {
        row.id: Item(
            row.date,
            (
                row.date,
                row.mode,
                row.start_time,
                row.end_time,
                row.duration,
                row.association_subject_id,
                row.service_name,
                tuple(sorted(row.tags or ())),
                row.topic,
                row.notes,
                tuple(sorted(teachers[row.id])),
                tuple(sorted(subjects[row.id])),
            ),
        )
        for row in rows
    }

    return (rows[0].student_tax_code if rows else None), lessons


# The pupil's lessons on those days, read before and after a write to compare them.
async def lessons_of(
    db: AsyncSession,
    pupil: str,
    days: Iterable[date],
) -> dict[int, Item]:
    _, lessons = await _read(
        db,
        and_(Presence.student_tax_code == pupil, Presence.date.in_(list(days))),
    )

    return lessons


# The pupil and the lessons of a presence or of one lesson, before and after a write.
async def pupil_lessons(
    db: AsyncSession,
    *,
    presence_id: int | None = None,
    booking_id: int | None = None,
) -> tuple[str | None, dict[int, Item]]:
    return await _read(
        db,
        Presence.id == presence_id
        if presence_id is not None
        else Booking.id == booking_id,
    )


# The pupil and the parents who read the pupil's bookings, all but who booked.
async def _readers(db: AsyncSession, pupil: str, booker: str) -> list[Account]:
    parents = await db.scalars(
        select(ParentalResponsibility.parent_tax_code).where(
            ParentalResponsibility.child_tax_code == pupil,
        )
    )
    repository = IdentityRepository(db)
    readers: list[Account] = []

    for tax_code in dict.fromkeys([pupil, *parents]):
        if tax_code == booker:
            continue

        account = await repository.get_account_identity(tax_code)

        if account is None or not is_reachable(account):
            continue

        if (
            "STUDENT" in RoleService.get_available_roles(account.person)
            if tax_code == pupil
            else pupil in RoleService.pupil_children_tax_codes(account.person)
        ):
            readers.append(account)

    return readers


async def _scene(
    db: AsyncSession,
    booker_tax_code: str,
    pupil_tax_code: str,
) -> Scene | None:
    booker = await db.get(Person, booker_tax_code)
    pupil = await db.get(Person, pupil_tax_code)

    if booker is None or pupil is None:
        return None

    return Scene(
        author=booker,
        owner=pupil,
        readers=await _readers(db, pupil_tax_code, booker_tax_code),
        pupil=pupil_tax_code,
    )


# Lessons booked for a pupil: their readers hear who booked them.
async def announce_bookings(
    db: AsyncSession,
    *,
    booker_tax_code: str,
    pupil_tax_code: str,
    lessons: Days,
) -> PushBatch:
    scene = await _scene(db, booker_tax_code, pupil_tax_code)

    if scene is None:
        return joined([])

    return await change_notices.announce(db, _BOOKINGS, scene, lessons)


async def cancel_bookings(
    db: AsyncSession,
    *,
    booker_tax_code: str,
    pupil_tax_code: str,
    lessons: Days,
) -> PushBatch:
    scene = await _scene(db, booker_tax_code, pupil_tax_code)

    if scene is None:
        return joined([])

    return await change_notices.cancel(db, _BOOKINGS, scene, lessons)


async def change_bookings(
    db: AsyncSession,
    *,
    booker_tax_code: str,
    pupil_tax_code: str,
    lessons: Mapping[int, tuple[Item, Item]],
) -> PushBatch:
    scene = await _scene(db, booker_tax_code, pupil_tax_code)

    if scene is None:
        return joined([])

    return await change_notices.change(db, _BOOKINGS, scene, lessons)


# A write's lessons before and after: the pupil and the parents hear what changed.
async def tell_changes(
    db: AsyncSession,
    *,
    booker_tax_code: str,
    pupil_tax_code: str,
    before: Mapping[int, Item],
    after: Mapping[int, Item],
) -> PushBatch:
    scene = await _scene(db, booker_tax_code, pupil_tax_code)

    if scene is None:
        return joined([])

    return await change_notices.tell_changes(db, _BOOKINGS, scene, before, after)


# That pupil's bookings of those days on screen: what told of them has done its work.
async def bookings_seen(
    db: AsyncSession,
    tax_code: str,
    pupil_tax_code: str,
    first: date,
    last: date,
) -> PushBatch:
    return await change_notices.seen(
        db,
        _BOOKINGS,
        tax_code,
        first,
        last,
        pupil=pupil_tax_code,
    )

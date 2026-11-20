import json
from collections import defaultdict
from collections.abc import Callable, Iterable
from datetime import date
from typing import Any, Final

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.labels import time_band_phrase
from app.core.time_band import TimeBandEnum, band_bounds, band_of
from app.models.account import Account
from app.models.availability import Availability
from app.models.booking import Booking
from app.models.calendar_activity import CalendarActivity
from app.models.lesson import Lesson
from app.models.notification import Notification, NotificationKindEnum
from app.models.opening_day import OpeningDay
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import GenderEnum
from app.models.presence import Presence
from app.services.notifications import (
    Bilingual,
    dismissals,
    fingerprint,
    notify,
    reachable_identities,
)
from app.services.push import PushBatch, joined
from app.services.role_service import RoleService

_PUPIL_TITLE: Final[Bilingual] = Bilingual(
    "Il calendario delle lezioni {band} è disponibile",
    "The {band} lesson calendar is available",
)
_PUPIL_BODY: Final[Bilingual] = Bilingual("Tocca per visualizzarlo", "Tap to view it")
_PUPIL_WEB_BODY: Final[Bilingual] = Bilingual(
    "Clicca per visualizzarlo",
    "Click to view it",
)

_CALLED_TITLES: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual("Sei stato convocato!", "You've been called in!"),
    GenderEnum.F: Bilingual("Sei stata convocata!", "You've been called in!"),
}
_CALLED_BODY: Final[Bilingual] = Bilingual(
    "Tocca per visualizzare il calendario delle lezioni {band}.",
    "Tap to view the {band} lesson calendar.",
)
_CALLED_WEB_BODY: Final[Bilingual] = Bilingual(
    "Clicca per visualizzare il calendario delle lezioni {band}.",
    "Click to view the {band} lesson calendar.",
)

_NOT_CALLED_TITLES: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual("Non sei stato convocato", "You haven't been called in"),
    GenderEnum.F: Bilingual("Non sei stata convocata", "You haven't been called in"),
}
_NOT_CALLED_BODY: Final[Bilingual] = Bilingual(
    "Grazie in ogni caso per aver dato la tua disponibilità",
    "Thank you anyway for giving your availability",
)

_NEWLY_CALLED_TITLES: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Le convocazioni sono cambiate: sei convocato!",
        "The call-ins have changed: you're called in!",
    ),
    GenderEnum.F: Bilingual(
        "Le convocazioni sono cambiate: sei convocata!",
        "The call-ins have changed: you're called in!",
    ),
}
_NO_LONGER_CALLED_TITLES: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Le convocazioni sono cambiate: non sei più convocato",
        "The call-ins have changed: you're no longer called in",
    ),
    GenderEnum.F: Bilingual(
        "Le convocazioni sono cambiate: non sei più convocata",
        "The call-ins have changed: you're no longer called in",
    ),
}

_CHANGED_TITLE: Final[Bilingual] = Bilingual(
    "Le lezioni {band} sono state modificate",
    "The {band} lessons have changed",
)
_CHANGED_BODY: Final[Bilingual] = Bilingual("Tocca per visualizzare", "Tap to view")
_CHANGED_WEB_BODY: Final[Bilingual] = Bilingual(
    "Clicca per visualizzare",
    "Click to view",
)
_CHANGED_BANDS: Final[dict[TimeBandEnum, str]] = {
    TimeBandEnum.MORNING: "del mattino",
    TimeBandEnum.AFTERNOON: "del pomeriggio",
    TimeBandEnum.EVENING: "della sera",
}


# The band in both languages, as each template wants it.
def _phrased(template: Bilingual, italian: str, band: TimeBandEnum) -> Bilingual:
    return Bilingual(
        template.it.format(band=italian),
        template.en.format(band=time_band_phrase(band, "en")),
    )

_PUBLISHED_KINDS: Final[list[NotificationKindEnum]] = [
    NotificationKindEnum.CALENDAR_PUBLISHED,
    NotificationKindEnum.CONVOCATION,
]


async def _booked(db: AsyncSession, day: date, band: TimeBandEnum) -> set[str]:
    rows = await db.execute(
        select(Presence.student_tax_code, Presence.start_time).where(
            Presence.date == day,
        )
    )

    return {code for code, start in rows if band_of(start) == band}


async def _parents_of(db: AsyncSession, children: set[str]) -> set[str]:
    return set(
        await db.scalars(
            select(ParentalResponsibility.parent_tax_code).where(
                ParentalResponsibility.child_tax_code.in_(children),
            )
        )
    )


async def _available(db: AsyncSession, day: date, band: TimeBandEnum) -> set[str]:
    start, end = band_bounds(band)

    return set(
        await db.scalars(
            select(Availability.teacher_tax_code).where(
                Availability.date == day,
                Availability.start_time < end,
                Availability.end_time > start,
            )
        )
    )


# A lesson or an activity on one of their availabilities in the band.
async def _called(db: AsyncSession, day: date, band: TimeBandEnum) -> set[str]:
    by_lesson = select(Availability.teacher_tax_code).join(
        Lesson,
        Lesson.availability_id == Availability.id,
    ).where(Lesson.date == day, Lesson.band == band)
    by_activity = select(Availability.teacher_tax_code).join(
        CalendarActivity,
        CalendarActivity.availability_id == Availability.id,
    ).where(CalendarActivity.date == day, CalendarActivity.band == band)

    return set(await db.scalars(by_lesson.union(by_activity)))


# Openings belong to the band they start in, as in calendar_hours_sync.
async def _online_only(db: AsyncSession, day: date, band: TimeBandEnum) -> bool:
    start, end = band_bounds(band)
    modes = await db.scalars(
        select(OpeningDay.mode).where(
            OpeningDay.date == day,
            OpeningDay.start_time >= start,
            OpeningDay.start_time < end,
        )
    )

    return set(modes) == {"online"}


# Families who booked the band and teachers available for it; nobody else hears.
Holding = Callable[[Iterable[str], str], list[str]]


async def _reach(db: AsyncSession) -> tuple[dict[str, Account], Holding]:
    accounts = {
        account.tax_code: account for account in await reachable_identities(db)
    }

    def holding(tax_codes: Iterable[str], role: str) -> list[str]:
        return sorted(
            code
            for code in set(tax_codes)
            if code in accounts
            and role in RoleService.get_available_roles(accounts[code].person)
        )

    return accounts, holding


Texts = tuple[Bilingual, Bilingual, Bilingual | None]


def _called_texts(title: Bilingual, band: TimeBandEnum) -> Texts:
    phrase = time_band_phrase(band, "it")

    return (
        title,
        _phrased(_CALLED_BODY, phrase, band),
        _phrased(_CALLED_WEB_BODY, phrase, band),
    )


def _not_called_texts(title: Bilingual) -> Texts:
    return title, _NOT_CALLED_BODY, None


# Teachers sharing a wording go out together.
async def _tell_teachers(
    db: AsyncSession,
    texts: dict[str, Texts],
    calendar: tuple[date, TimeBandEnum],
) -> list[PushBatch]:
    groups: dict[Texts, list[str]] = defaultdict(list)

    for code, wording in texts.items():
        groups[wording].append(code)

    return [
        await notify(
            db,
            teachers,
            kind=NotificationKindEnum.CONVOCATION,
            title=title,
            body=body,
            web_body=web_body,
            calendar=calendar,
        )
        for (title, body, web_body), teachers in groups.items()
    ]


async def announce_publication(
    db: AsyncSession,
    day: date,
    band: TimeBandEnum,
) -> PushBatch:
    accounts, holding = await _reach(db)

    booked = await _booked(db, day, band)
    pupils = holding(booked, "STUDENT") + holding(
        await _parents_of(db, booked) if booked else set(),
        "PARENT",
    )
    batches = [
        await notify(
            db,
            pupils,
            kind=NotificationKindEnum.CALENDAR_PUBLISHED,
            title=_phrased(_PUPIL_TITLE, time_band_phrase(band, "it"), band),
            body=_PUPIL_BODY,
            web_body=_PUPIL_WEB_BODY,
            calendar=(day, band),
        ),
    ]

    called = await _called(db, day, band)
    online_only = await _online_only(db, day, band)
    texts: dict[str, Texts] = {}

    # An online-only band tells only those called.
    for code in holding(await _available(db, day, band), "TEACHER"):
        gender = accounts[code].person.gender

        if code in called:
            texts[code] = _called_texts(_CALLED_TITLES[gender], band)
        elif not online_only:
            texts[code] = _not_called_texts(_NOT_CALLED_TITLES[gender])

    batches.extend(await _tell_teachers(db, texts, (day, band)))

    return joined(batches)


# Sorted keys: a stored draft comes back from JSONB with its keys reordered.
def _key(rows: Iterable[dict[str, Any]]) -> str:
    return json.dumps(
        sorted(rows, key=lambda row: json.dumps(row, sort_keys=True)),
        sort_keys=True,
    )


# What each teacher and each pupil sees of a snapshot of the band.
def _views(
    snapshot: dict[str, Any],
    pupil_of: dict[int, str],
) -> tuple[dict[str, str], dict[str, str]]:
    rooms = {
        row["teacher_tax_code"]: row["room_id"]
        for row in snapshot.get("assignments", [])
    }
    teachers: dict[str, list[dict[str, Any]]] = defaultdict(list)
    pupils: dict[str, list[dict[str, Any]]] = defaultdict(list)

    for part in ("lessons", "activities", "assignments", "supervisions"):
        for row in snapshot.get(part, []):
            if row.get("teacher_tax_code") is not None:
                teachers[row["teacher_tax_code"]].append({"part": part, **row})

    for lesson in snapshot.get("lessons", []):
        seen = {
            key: value
            for key, value in lesson.items()
            if key not in ("bookings", "availability_id")
        }

        for booking in lesson["bookings"]:
            if booking in pupil_of:
                pupils[pupil_of[booking]].append(
                    {
                        **seen,
                        "booking": booking,
                        "room": rooms.get(lesson["teacher_tax_code"]),
                    }
                )

    return (
        {code: _key(rows) for code, rows in teachers.items()},
        {code: _key(rows) for code, rows in pupils.items()},
    )


# Called in a snapshot as in _called: a lesson or an activity of theirs.
def _called_in(snapshot: dict[str, Any]) -> set[str]:
    return {
        row["teacher_tax_code"]
        for part in ("lessons", "activities")
        for row in snapshot.get(part, [])
        if row.get("teacher_tax_code") is not None
    }


def _changed(before: dict[str, str], after: dict[str, str]) -> set[str]:
    return {
        code
        for code in before.keys() | after.keys()
        if before.get(code) != after.get(code)
    }


# The parents of those pupils, each with all their children: a family sees them all.
async def _families(db: AsyncSession, pupils: set[str]) -> dict[str, set[str]]:
    if not pupils:
        return {}

    parents = select(ParentalResponsibility.parent_tax_code).where(
        ParentalResponsibility.child_tax_code.in_(pupils),
    )
    rows = await db.execute(
        select(
            ParentalResponsibility.parent_tax_code,
            ParentalResponsibility.child_tax_code,
        ).where(ParentalResponsibility.parent_tax_code.in_(parents))
    )
    children: dict[str, set[str]] = defaultdict(set)

    for parent, child in rows:
        children[parent].add(child)

    return children


def _family_view(views: dict[str, str], children: set[str]) -> str:
    return json.dumps({child: views.get(child) for child in sorted(children)})


# Sent again: only those whose own part changed hear, and their earlier notice goes.
# A part restored to what its reader knew withdraws the news; an unseen first returns.
async def announce_changes(
    db: AsyncSession,
    day: date,
    band: TimeBandEnum,
    before: dict[str, Any],
    after: dict[str, Any],
) -> PushBatch:
    bookings = {
        booking
        for snapshot in (before, after)
        for lesson in snapshot.get("lessons", [])
        for booking in lesson["bookings"]
    }
    rows = await db.execute(
        select(Booking.id, Presence.student_tax_code)
        .join(Presence, Presence.id == Booking.presence_id)
        .where(Booking.id.in_(bookings))
    )
    pupil_of = dict(rows.tuples().all())

    teachers_before, pupils_before = _views(before, pupil_of)
    teachers_after, pupils_after = _views(after, pupil_of)
    pupils = _changed(pupils_before, pupils_after)

    accounts, holding = await _reach(db)
    children = await _families(db, pupils)
    families = _PUBLISHED_KINDS[0]
    convocations = _PUBLISHED_KINDS[1]

    # Each reader's part before and after, by the kind of notice it is told in.
    parts: dict[tuple[NotificationKindEnum, str], tuple[str, str]] = {}

    for code in holding(pupils, "STUDENT"):
        parts[(families, code)] = (
            pupils_before.get(code, ""),
            pupils_after.get(code, ""),
        )

    for code in holding(children, "PARENT"):
        parts[(families, code)] = (
            _family_view(pupils_before, children[code]),
            _family_view(pupils_after, children[code]),
        )

    for code in holding(_changed(teachers_before, teachers_after), "TEACHER"):
        parts[(convocations, code)] = (
            teachers_before.get(code, ""),
            teachers_after.get(code, ""),
        )

    live: dict[tuple[NotificationKindEnum, str], list[Notification]] = defaultdict(list)

    for row in await db.scalars(
        select(Notification).where(
            Notification.kind.in_(_PUBLISHED_KINDS),
            Notification.calendar_date == day,
            Notification.calendar_band == band,
            Notification.withdrawn_at.is_(None),
            Notification.account_tax_code.in_({code for _, code in parts}),
        )
    ):
        live[(row.kind, row.account_tax_code)].append(row)

    changed: Texts = (
        _phrased(_CHANGED_TITLE, _CHANGED_BANDS[band], band),
        _CHANGED_BODY,
        _CHANGED_WEB_BODY,
    )
    called_before = _called_in(before)
    called_after = _called_in(after)
    online_only = await _online_only(db, day, band)

    # The first notice, as announce_publication words it for that reader.
    def first(kind: NotificationKindEnum, code: str) -> Texts | None:
        if kind == families:
            return (
                _phrased(_PUPIL_TITLE, time_band_phrase(band, "it"), band),
                _PUPIL_BODY,
                _PUPIL_WEB_BODY,
            )

        gender = accounts[code].person.gender

        if code in called_after:
            return _called_texts(_CALLED_TITLES[gender], band)

        if online_only:
            return None

        return _not_called_texts(_NOT_CALLED_TITLES[gender])

    # A convocation gained or lost says so instead of "modificate".
    def news(kind: NotificationKindEnum, code: str) -> Texts:
        if kind == families:
            return changed

        gender = accounts[code].person.gender

        if code in called_after - called_before:
            return _called_texts(_NEWLY_CALLED_TITLES[gender], band)

        if code in called_before - called_after:
            return _not_called_texts(_NO_LONGER_CALLED_TITLES[gender])

        return changed

    gone: list[Notification] = []
    groups: dict[tuple[NotificationKindEnum, Texts, str], list[str]] = defaultdict(list)

    for (kind, code), (part_before, part_after) in parts.items():
        earlier = live.get((kind, code), [])
        marked = next((row.known for row in earlier if row.known), None)
        known = marked or {
            "view": fingerprint(part_before),
            "unseen": bool(earlier),
        }

        for row in earlier:
            row.withdrawn_at = func.now()
            gone.append(row)

        if fingerprint(part_after) != known["view"]:
            groups[(kind, news(kind, code), json.dumps(known))].append(code)
        elif known["unseen"] and (wording := first(kind, code)) is not None:
            groups[(kind, wording, "")].append(code)

    batches = [await dismissals(db, [row for row in gone if row.read_at is None])]

    for (kind, (title, body, web_body), known), codes in groups.items():
        batches.append(
            await notify(
                db,
                codes,
                kind=kind,
                title=title,
                body=body,
                web_body=web_body,
                calendar=(day, band),
                known=json.loads(known) if known else None,
            )
        )

    return joined(batches)

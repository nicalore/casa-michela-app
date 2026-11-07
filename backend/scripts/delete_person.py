# Erases a person, with what the foreign keys alone would refuse or take from others.
#
#     python -m scripts.delete_person RSSMRA80A01H501U
#     python -m scripts.delete_person RSSMRA80A01H501U --writings delete --apply
#
# Without --apply the whole erasure runs, is reported and is rolled back. What the
# person wrote or pinned needs --writings: "delete", or the tax code of who takes it.
# Their lessons go, past ones too: a lesson cannot outlive its teacher or pupil.
# Bookings made for others stay, under another parent or the pupil. Nobody is told.

import argparse
import asyncio
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Final

from sqlalchemy import String, cast, delete, func, or_, select, update
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import storage
from app.core.booking_window import today_in_rome
from app.core.config import settings
from app.db.base import Base
from app.db.session import AsyncSessionLocal, engine
from app.models.administrator_note import AdministratorNote
from app.models.app_update import AppUpdate
from app.models.availability import Availability
from app.models.booking import Booking
from app.models.calendar_activity import CalendarActivity
from app.models.calendar_publication import CalendarPublication
from app.models.lesson import Lesson
from app.models.lesson_booking import LessonBooking
from app.models.methodological_note import MethodologicalNote
from app.models.notice import Notice, NoticePin
from app.models.parental_responsibility import ParentalResponsibility
from app.models.person import Person
from app.models.presence import Presence
from app.models.teacher_note import TeacherNote
from app.models.teacher_room_assignment import TeacherRoomAssignment
from app.models.technical_note import TechnicalNote
from app.services.calendar_snapshot import without_teacher

DELETE_WRITINGS: Final[str] = "delete"

# No cascade on purpose: each outlives its author's role, so each needs a decision.
_WRITINGS: Final = (
    (MethodologicalNote, MethodologicalNote.author_tax_code),
    (TechnicalNote, TechnicalNote.author_tax_code),
    (TeacherNote, TeacherNote.author_tax_code),
    (AdministratorNote, AdministratorNote.author_tax_code),
    (Notice, Notice.author_tax_code),
    (NoticePin, NoticePin.pinned_by_tax_code),
    (AppUpdate, AppUpdate.author_tax_code),
)


@dataclass(frozen=True)
class Erasure:
    removed: dict[str, int]
    upcoming_lessons: list[tuple[date, str]]
    mentions: dict[str, int]


async def writings_of(db: AsyncSession, tax_code: str) -> dict[str, int]:
    counts: dict[str, int] = {}

    for model, column in _WRITINGS:
        count = await db.scalar(select(func.count()).where(column == tax_code))

        if count:
            counts[model.__tablename__] = count

    return counts


async def _settle_writings(db: AsyncSession, tax_code: str, writings: str) -> None:
    for model, column in _WRITINGS:
        if writings == DELETE_WRITINGS:
            await db.execute(delete(model).where(column == tax_code))
        else:
            await db.execute(
                update(model).where(column == tax_code).values({column.key: writings}),
            )


# The rule of the booker hook: a parent answers for the pupil, or nobody but them.
async def _hand_over_bookings(db: AsyncSession, tax_code: str) -> None:
    other_parent = (
        select(ParentalResponsibility.parent_tax_code)
        .where(
            ParentalResponsibility.child_tax_code == Presence.student_tax_code,
            ParentalResponsibility.parent_tax_code != tax_code,
        )
        .order_by(ParentalResponsibility.parent_tax_code)
        .limit(1)
        .correlate(Presence)
        .scalar_subquery()
    )

    await db.execute(
        update(Presence)
        .where(
            Presence.booker_tax_code == tax_code,
            Presence.student_tax_code != tax_code,
        )
        .values(
            booker_tax_code=func.coalesce(other_parent, Presence.student_tax_code),
        )
        .execution_options(synchronize_session=False),
    )


# A lesson has one pupil, so a pupil's lessons go whole. The other side's hours stay.
async def _remove_lessons(
    db: AsyncSession,
    tax_code: str,
) -> list[tuple[date, str]]:
    taught = select(Availability.id).where(Availability.teacher_tax_code == tax_code)
    attended = (
        select(LessonBooking.lesson_id)
        .join(Booking, Booking.id == LessonBooking.booking_id)
        .join(Presence, Presence.id == Booking.presence_id)
        .where(Presence.student_tax_code == tax_code)
    )

    gone = await db.execute(
        delete(Lesson)
        .where(or_(Lesson.availability_id.in_(taught), Lesson.id.in_(attended)))
        .returning(Lesson.date, Lesson.band)
        .execution_options(synchronize_session=False),
    )
    today = today_in_rome()

    return sorted((day, band) for day, band in gone.tuples() if day >= today)


async def _leave_the_calendar(db: AsyncSession, tax_code: str) -> None:
    taught = select(Availability.id).where(Availability.teacher_tax_code == tax_code)

    await db.execute(
        update(CalendarActivity)
        .where(CalendarActivity.availability_id.in_(taught))
        .values(
            availability_id=None,
            teacher_mode=None,
            start_time=None,
            end_time=None,
        )
        .execution_options(synchronize_session=False),
    )
    await db.execute(
        delete(TeacherRoomAssignment).where(
            TeacherRoomAssignment.teacher_tax_code == tax_code,
        ),
    )

    drafts = await db.execute(
        select(
            CalendarPublication.date,
            CalendarPublication.band,
            CalendarPublication.draft_snapshot,
        ).where(CalendarPublication.draft_snapshot.is_not(None)),
    )

    for day, band, snapshot in drafts.tuples().all():
        if snapshot is None or tax_code not in str(snapshot):
            continue

        await db.execute(
            update(CalendarPublication)
            .where(CalendarPublication.date == day, CalendarPublication.band == band)
            .values(draft_snapshot=without_teacher(snapshot, tax_code)),
        )


async def _row_counts(db: AsyncSession) -> dict[str, int]:
    return {
        table.name: await db.scalar(select(func.count()).select_from(table)) or 0
        for table in Base.metadata.sorted_tables
    }


# Free text and JSON hold no foreign key: nothing but a search can find these.
async def _mentions(db: AsyncSession, needles: tuple[str, ...]) -> dict[str, int]:
    found: dict[str, int] = {}

    for table in Base.metadata.sorted_tables:
        for column in table.columns:
            if not isinstance(column.type, String | JSONB):
                continue

            as_text = cast(column, String)
            count = await db.scalar(
                select(func.count())
                .select_from(table)
                .where(
                    or_(
                        *(
                            as_text.icontains(needle, autoescape=True)
                            for needle in needles
                        ),
                    ),
                ),
            )

            if count:
                found[f"{table.name}.{column.name}"] = count

    return found


# Leaves the transaction open: the caller commits it or rolls it back.
async def erase(db: AsyncSession, person: Person, writings: str | None) -> Erasure:
    tax_code = person.tax_code
    needles = (
        tax_code,
        f"{person.first_name} {person.last_name}",
        f"{person.last_name} {person.first_name}",
    )
    before = await _row_counts(db)

    if writings is not None:
        await _settle_writings(db, tax_code, writings)

    await _hand_over_bookings(db, tax_code)
    upcoming_lessons = await _remove_lessons(db, tax_code)
    await _leave_the_calendar(db, tax_code)
    await db.execute(delete(Person).where(Person.tax_code == tax_code))

    after = await _row_counts(db)

    return Erasure(
        removed={
            name: before[name] - after[name]
            for name in sorted(before)
            if before[name] != after[name]
        },
        upcoming_lessons=upcoming_lessons,
        mentions=await _mentions(db, needles),
    )


def remove_photo(url: str | None) -> bool:
    if url is None:
        return False

    found = (storage.PROFILE_IMAGES_DIR / Path(url).name).exists()
    storage.discard_profile_image(url)

    return found


def _audit_logs_naming(tax_code: str) -> list[str]:
    folder = Path(settings.audit_log_path).parent

    return sorted(
        log.name
        for log in folder.glob("audit_*.log")
        if tax_code in log.read_text(errors="ignore")
    )


def _report(erasure: Erasure, tax_code: str) -> None:
    print("\nRows removed:")

    for table, count in erasure.removed.items():
        print(f"  {table}: {count}")

    if erasure.upcoming_lessons:
        print("\nLessons from today on, to place again for whoever is left:")

        for day, band in erasure.upcoming_lessons:
            print(f"  {day} {band}")

    if erasure.mentions:
        print("\nStill naming them, left as they are:")

        for column, count in erasure.mentions.items():
            print(f"  {column}: {count}")

    logs = _audit_logs_naming(tax_code)

    if logs:
        print(f"\nAudit logs with their tax code, left as they are: {len(logs)}")


async def _run(tax_code: str, writings: str | None, apply: bool) -> int:
    async with AsyncSessionLocal() as db:
        person = await db.get(Person, tax_code)

        if person is None:
            print(f"No person with tax code {tax_code}.")

            return 1

        print(f"Database: {engine.url.database} on {engine.url.host}")
        print(f"Person: {person.first_name} {person.last_name} ({tax_code})")

        pending = await writings_of(db, tax_code)

        if pending and writings is None:
            print("\nThey wrote or pinned these, for others to read:")

            for table, count in pending.items():
                print(f"  {table}: {count}")

            print(f'\nChoose with --writings: "{DELETE_WRITINGS}", or a tax code.')

            return 1

        if writings not in (None, DELETE_WRITINGS) and (
            writings == tax_code or await db.get(Person, writings) is None
        ):
            print(f"Nobody else has tax code {writings}.")

            return 1

        if apply and input("\nType the tax code to erase for good: ") != tax_code:
            print("Cancelled: nothing was changed.")

            return 1

        photo = person.profile_image_url
        erasure = await erase(db, person, writings)
        _report(erasure, tax_code)

        if not apply:
            await db.rollback()
            print("\nPreview: nothing was changed. Add --apply to erase.")

            return 0

        await db.commit()

    # After the commit: a failed erasure keeps both.
    if photo is not None and not remove_photo(photo):
        print(f"\nPhoto not found in {storage.PROFILE_IMAGES_DIR}: remove it by hand.")

    print("\nErased. Database backups still hold them until they expire.")

    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description="Erase a person for good.")
    parser.add_argument("tax_code", type=str.upper)
    parser.add_argument(
        "--writings",
        help=f'"{DELETE_WRITINGS}", or the tax code of who takes them over',
    )
    parser.add_argument("--apply", action="store_true", help="commit the erasure")
    args = parser.parse_args()

    writings = args.writings

    if writings is not None and writings.lower() != DELETE_WRITINGS:
        writings = writings.upper()
    elif writings is not None:
        writings = DELETE_WRITINGS

    sys.exit(asyncio.run(_run(args.tax_code, writings, args.apply)))


if __name__ == "__main__":
    main()

from typing import Final

from sqlalchemy import ColumnElement, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification, NotificationKindEnum
from app.models.person import GenderEnum, Person
from app.models.teacher_note import TeacherNote
from app.services.notifications import dismissals, notify, reachable_administrators
from app.services.push import PushBatch

_KIND: Final[NotificationKindEnum] = NotificationKindEnum.TEACHER_NOTE_ADDED

_TITLE: Final[str] = "{author} ha inserito una nuova osservazione per {pupil}"
_PUPIL: Final[dict[GenderEnum, str]] = {
    GenderEnum.M: "lo studente {name}",
    GenderEnum.F: "la studentessa {name}",
}
_BODY: Final[str] = "Tocca per visualizzare"
_WEB_BODY: Final[str] = "Clicca per visualizzare"


def _full_name(person: Person) -> str:
    return f"{person.first_name} {person.last_name}"


# Every administrator but its author; the caller commits, then delivers the pushes.
async def announce_teacher_note(db: AsyncSession, note: TeacherNote) -> PushBatch:
    await db.flush()

    people = {
        person.tax_code: person
        for person in await db.scalars(
            select(Person).where(
                Person.tax_code.in_([note.author_tax_code, note.student_tax_code]),
            )
        )
    }
    author = people[note.author_tax_code]
    pupil = people[note.student_tax_code]

    return await notify(
        db,
        [
            tax_code
            for tax_code in await reachable_administrators(db)
            if tax_code != author.tax_code
        ],
        kind=_KIND,
        title=_TITLE.format(
            author=_full_name(author),
            pupil=_PUPIL[pupil.gender].format(name=_full_name(pupil)),
        ),
        body=_BODY,
        web_body=_WEB_BODY,
        pupil_tax_code=pupil.tax_code,
        author_tax_code=author.tax_code,
        teacher_note_id=note.id,
    )


# The pupil's notes on the reader's screen: their news has done its work.
async def teacher_notes_seen(
    db: AsyncSession,
    tax_code: str,
    pupil_tax_code: str,
) -> PushBatch:
    rows = await _withdraw(
        db,
        Notification.account_tax_code == tax_code,
        Notification.pupil_tax_code == pupil_tax_code,
    )

    return await dismissals(db, [row for row in rows if row.read_at is None])


# Deleted: nobody is told of it any more.
async def teacher_note_deleted(db: AsyncSession, note_id: int) -> PushBatch:
    rows = await _withdraw(db, Notification.teacher_note_id == note_id)

    # Read ones too: the push is what makes every device drop it from its card.
    return await dismissals(db, rows)


async def _withdraw(
    db: AsyncSession,
    *where: ColumnElement[bool],
) -> list[Notification]:
    return list(
        await db.scalars(
            update(Notification)
            .where(
                Notification.kind == _KIND,
                Notification.withdrawn_at.is_(None),
                *where,
            )
            .values(withdrawn_at=func.now())
            .returning(Notification)
        )
    )

from collections import defaultdict
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass
from datetime import date
from typing import Any, Final

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account
from app.models.notification import Notification, NotificationKindEnum
from app.models.person import Person
from app.services.notification_kinds import holds_kind
from app.services.notifications import dismissals, fingerprint, notify
from app.services.push import PushBatch, joined

_FOR: Final[str] = "{title} per {owner}"

# Each item's id with its day.
Days = Mapping[int, date]


@dataclass(frozen=True)
class Item:
    day: date
    # All a reader could see change of it.
    shape: tuple[object, ...]

    @property
    def fingerprint(self) -> str:
        return fingerprint(self.shape)


# The phone taps, the desktop clicks; {author} is who wrote.
@dataclass(frozen=True)
class Texts:
    one: str
    many: str
    body_one: str
    web_body_one: str
    body_many: str
    web_body_many: str


# What someone else wrote for another: the kinds its news is told in, and the words.
@dataclass(frozen=True)
class Topic:
    added: NotificationKindEnum
    changed: NotificationKindEnum
    cancelled: NotificationKindEnum
    texts: Mapping[NotificationKindEnum, Texts]


# Who wrote, whose the items are and who hears; pupil names a pupil's bookings.
@dataclass(frozen=True)
class Scene:
    author: Person
    owner: Person
    readers: Sequence[Account]
    pupil: str | None = None


def _full_name(person: Person) -> str:
    return f"{person.first_name} {person.last_name}"


def _first_day(known: dict[str, Any]) -> date:
    return min(date.fromisoformat(entry["day"]) for entry in known.values())


# Worded for the items it tells of now; the owner named to anyone else.
def _word(
    row: Notification,
    texts: Texts,
    author: Person,
    owner: Person,
) -> None:
    many = len(row.item_ids or ()) > 1
    title = (texts.many if many else texts.one).format(author=_full_name(author))

    if owner.tax_code not in (row.account_tax_code, author.tax_code):
        title = _FOR.format(title=title, owner=owner.first_name)

    row.title = title
    row.body = texts.body_many if many else texts.body_one
    row.web_body = texts.web_body_many if many else texts.web_body_one


# One notice per reader, author and owner: a later one takes the place of the one
# not seen yet, telling of its items too.
async def _tell(
    db: AsyncSession,
    topic: Topic,
    kind: NotificationKindEnum,
    reader: str,
    scene: Scene,
    known: Mapping[int, dict[str, str]],
) -> PushBatch:
    live = list(
        await db.scalars(
            update(Notification)
            .where(
                Notification.kind == kind,
                Notification.account_tax_code == reader,
                Notification.author_tax_code == scene.author.tax_code,
                Notification.pupil_tax_code == scene.pupil,
                Notification.withdrawn_at.is_(None),
            )
            .values(withdrawn_at=func.now())
            .returning(Notification)
        )
    )
    merged: dict[str, Any] = {}

    for row in live:
        merged.update(row.known or {})

    merged.update({str(i): entry for i, entry in known.items()})
    told = Notification(
        account_tax_code=reader,
        kind=kind,
        item_ids=sorted(int(i) for i in merged),
    )
    _word(told, topic.texts[kind], scene.author, scene.owner)

    return joined(
        [
            await dismissals(db, [row for row in live if row.read_at is None]),
            await notify(
                db,
                [reader],
                kind=kind,
                title=told.title,
                body=told.body,
                web_body=told.web_body,
                calendar=_first_day(merged),
                pupil_tax_code=scene.pupil,
                author_tax_code=scene.author.tax_code,
                item_ids=told.item_ids,
                known=merged,
            ),
        ]
    )


# Items no longer to tell of leave the notices telling of them, which are worded
# anew or, once they tell of none, go.
async def _trim(
    db: AsyncSession,
    topic: Topic,
    rows: Iterable[Notification],
    gone: set[int],
) -> PushBatch:
    emptied: list[Notification] = []

    for row in rows:
        left = [i for i in row.item_ids or () if i not in gone]

        if left == row.item_ids:
            continue

        row.item_ids = left
        row.known = {
            key: entry
            for key, entry in (row.known or {}).items()
            if int(key) not in gone
        }

        if not left:
            row.withdrawn_at = func.now()
            emptied.append(row)

            continue

        if row.known:
            row.calendar_date = _first_day(row.known)

        author = await db.get(Person, row.author_tax_code)
        owner = await db.get(Person, row.pupil_tax_code or row.account_tax_code)

        if author is not None and owner is not None:
            _word(row, topic.texts[row.kind], author, owner)

    return await dismissals(db, [row for row in emptied if row.read_at is None])


def _days(items: Days) -> dict[int, dict[str, str]]:
    return {i: {"day": day.isoformat()} for i, day in items.items()}


async def announce(
    db: AsyncSession,
    topic: Topic,
    scene: Scene,
    items: Days,
) -> PushBatch:
    if not items:
        return joined([])

    return joined(
        [
            await _tell(db, topic, topic.added, reader.tax_code, scene, _days(items))
            for reader in scene.readers
            if holds_kind(reader, topic.added)
        ]
    )


# Those whose arrival was not seen yet leave the notices that told of them, as from
# the notices of their changes; the other readers hear who cancelled the rest.
async def cancel(
    db: AsyncSession,
    topic: Topic,
    scene: Scene,
    items: Days,
) -> PushBatch:
    if not items:
        return joined([])

    rows = list(
        await db.scalars(
            select(Notification).where(
                Notification.kind.in_([topic.added, topic.changed]),
                Notification.withdrawn_at.is_(None),
                Notification.item_ids.overlap(list(items)),
            )
        )
    )
    unseen: dict[str, set[int]] = defaultdict(set)

    for row in rows:
        if row.kind == topic.added:
            unseen[row.account_tax_code].update(
                i for i in row.item_ids or () if i in items
            )

    batches = [await _trim(db, topic, rows, set(items))]

    for reader in scene.readers:
        seen = {
            i: day for i, day in items.items() if i not in unseen[reader.tax_code]
        }

        if seen and holds_kind(reader, topic.cancelled):
            batches.append(
                await _tell(
                    db,
                    topic,
                    topic.cancelled,
                    reader.tax_code,
                    scene,
                    _days(seen),
                )
            )

    return joined(batches)

async def change(
    db: AsyncSession,
    topic: Topic,
    scene: Scene,
    items: Mapping[int, tuple[Item, Item]],
) -> PushBatch:
    if not items:
        return joined([])

    batches: list[PushBatch] = []

    for reader in scene.readers:
        if not holds_kind(reader, topic.changed):
            continue

        live = list(
            await db.scalars(
                select(Notification).where(
                    Notification.kind == topic.changed,
                    Notification.account_tax_code == reader.tax_code,
                    Notification.withdrawn_at.is_(None),
                    Notification.item_ids.overlap(list(items)),
                )
            )
        )
        knew = {
            int(key): entry["knew"]
            for row in live
            for key, entry in (row.known or {}).items()
            if "knew" in entry
        }
        undone = {
            i
            for i, (old, new) in items.items()
            if new.fingerprint == knew.get(i, old.fingerprint)
        }
        batches.append(await _trim(db, topic, live, undone))

        told = {
            i: {"day": new.day.isoformat(), "knew": knew.get(i, old.fingerprint)}
            for i, (old, new) in items.items()
            if i not in undone
        }

        if told:
            batches.append(
                await _tell(db, topic, topic.changed, reader.tax_code, scene, told)
            )

    return joined(batches)


# A write's items before and after: those gone were cancelled, those come were added,
# those reshaped were changed; the day told is the one each has now. Who wrote knows
# them as they are: the news of them to that person is past.
async def tell_changes(
    db: AsyncSession,
    topic: Topic,
    scene: Scene,
    before: Mapping[int, Item],
    after: Mapping[int, Item],
) -> PushBatch:
    touched = set(before) | set(after)
    own = await db.scalars(
        select(Notification).where(
            Notification.kind.in_([topic.added, topic.changed, topic.cancelled]),
            Notification.account_tax_code == scene.author.tax_code,
            Notification.withdrawn_at.is_(None),
            Notification.item_ids.overlap(list(touched)),
        )
    )

    return joined(
        [
            await _trim(db, topic, own, touched),
            await cancel(
                db,
                topic,
                scene,
                {i: item.day for i, item in before.items() if i not in after},
            ),
            await announce(
                db,
                topic,
                scene,
                {i: item.day for i, item in after.items() if i not in before},
            ),
            await change(
                db,
                topic,
                scene,
                {
                    i: (before[i], item)
                    for i, item in after.items()
                    if i in before and before[i].shape != item.shape
                },
            ),
        ]
    )


# Those days on screen, of that pupil's bookings when named: their news is seen.
async def seen(
    db: AsyncSession,
    topic: Topic,
    tax_code: str,
    first: date,
    last: date,
    *,
    pupil: str | None = None,
) -> PushBatch:
    statement = (
        update(Notification)
        .where(
            Notification.kind.in_([topic.added, topic.changed, topic.cancelled]),
            Notification.account_tax_code == tax_code,
            Notification.calendar_date.between(first, last),
            Notification.withdrawn_at.is_(None),
        )
        .values(withdrawn_at=func.now())
        .returning(Notification)
    )

    if pupil is not None:
        statement = statement.where(Notification.pupil_tax_code == pupil)

    rows = list(await db.scalars(statement))

    return await dismissals(db, [row for row in rows if row.read_at is None])

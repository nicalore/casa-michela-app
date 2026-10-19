"""One discipline per booking, lessons from a quarter of an hour

Revision ID: e3b6a9d2c471
Revises: a7c4e1f9b356
Create Date: 2026-10-13
"""

from collections import defaultdict
from datetime import date, datetime, time, timedelta

import sqlalchemy as sa

from alembic import op

revision = "e3b6a9d2c471"
down_revision = "a7c4e1f9b356"
branch_labels = None
depends_on = None

_QUARTER = 15
_HALF_HOUR = 30


def _replace_check(table: str, name: str, sql: str) -> None:
    op.drop_constraint(op.f(f"ck_{table}_{name}"), table, type_="check")
    op.create_check_constraint(op.f(f"ck_{table}_{name}"), table, sql)


def _shift(at: time, minutes: int) -> time:
    return (datetime.combine(date.min, at) + timedelta(minutes=minutes)).time()


def _length(start: time, end: time) -> int:
    return (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute)


# Quarter hours dealt out like cards, the first parts taking any odd one.
def _equal_parts(minutes: int, count: int) -> list[int]:
    quarters = minutes // _QUARTER

    return [
        (quarters // count + (1 if index < quarters % count else 0)) * _QUARTER
        for index in range(count)
    ]


# Unplanned time goes to whoever has least, so an unplanned booking splits evenly.
def _shares(duration: int, taught: dict[int, int], order: list[int]) -> list[int]:
    shares = [taught.get(discipline, 0) for discipline in order]

    for _ in range((duration - sum(shares)) // _QUARTER):
        least = shares.index(min(shares))
        shares[least] += _QUARTER

    return shares


class _Unsplittable(Exception):
    pass


def _split_booking(
    connection: sa.Connection,
    booking_id: int,
    duration: int,
    order: list[int],
) -> None:
    lessons = connection.execute(
        sa.text(
            "SELECT l.id, l.start_time, l.end_time FROM lessons l "
            "JOIN lesson_bookings lb ON lb.lesson_id = l.id "
            "WHERE lb.booking_id = :booking ORDER BY l.start_time",
        ),
        {"booking": booking_id},
    ).all()

    # Per lesson, its slices: (discipline or None, start, end).
    slices: dict[int, list[tuple[int | None, time, time]]] = {}
    taught: dict[int, int] = defaultdict(int)
    shortest: dict[int, int] = {}

    for lesson_id, start, end in lessons:
        disciplines = set(
            connection.scalars(
                sa.text(
                    "SELECT association_subject_id FROM lesson_disciplines "
                    "WHERE lesson_id = :lesson",
                ),
                {"lesson": lesson_id},
            ).all(),
        )
        mine = [discipline for discipline in order if discipline in disciplines]

        if len(mine) <= 1:
            slices[lesson_id] = [(mine[0] if mine else None, start, end)]

            if mine:
                taught[mine[0]] += _length(start, end)

            continue

        shared = connection.scalar(
            sa.text(
                "SELECT count(*) FROM lesson_bookings "
                "WHERE lesson_id = :lesson AND booking_id <> :booking",
            ),
            {"lesson": lesson_id, "booking": booking_id},
        )
        parts = _equal_parts(_length(start, end), len(mine))

        if shared or min(parts) < _QUARTER:
            raise _Unsplittable

        slices[lesson_id] = []

        for discipline, minutes in zip(mine, parts, strict=True):
            slices[lesson_id].append((discipline, start, _shift(start, minutes)))
            taught[discipline] += minutes
            shortest[discipline] = min(minutes, shortest.get(discipline, minutes))
            start = _shift(start, minutes)

    shares = _shares(duration, taught, order)

    # A quarter-hour lesson stands only as the whole of its booking.
    if min(shares) < _QUARTER or any(
        share >= _HALF_HOUR and shortest.get(discipline, share) < _HALF_HOUR
        for discipline, share in zip(order, shares, strict=True)
    ):
        raise _Unsplittable

    # The first discipline stays on the booking, the others get a copy each.
    booking_of: dict[int | None, int] = {order[0]: booking_id}

    connection.execute(
        sa.text(
            "UPDATE bookings SET duration = :duration, updated_at = now() "
            "WHERE id = :booking",
        ),
        {"duration": shares[0], "booking": booking_id},
    )

    for discipline, share in zip(order[1:], shares[1:], strict=True):
        copy = connection.scalar(
            sa.text(
                "INSERT INTO bookings (presence_id, duration, created_at, "
                "updated_at, topic, notes, tags) "
                "SELECT presence_id, :duration, created_at, now(), topic, notes, "
                "tags FROM bookings WHERE id = :booking RETURNING id",
            ),
            {"duration": share, "booking": booking_id},
        )
        booking_of[discipline] = copy

        connection.execute(
            sa.text(
                "UPDATE subjects_requested SET booking_id = :copy "
                "WHERE booking_id = :booking AND association_subject_id = :subject",
            ),
            {"copy": copy, "booking": booking_id, "subject": discipline},
        )

        for table, columns in (
            ("booking_preferred_teachers", "teacher_tax_code"),
            ("competence_waivers", "teacher_tax_code, created_at"),
        ):
            connection.execute(
                sa.text(
                    f"INSERT INTO {table} (booking_id, {columns}) "
                    f"SELECT :copy, {columns} FROM {table} "
                    "WHERE booking_id = :booking",
                ),
                {"copy": copy, "booking": booking_id},
            )

    for lesson_id, pieces in slices.items():
        first, start, end = pieces[0]

        connection.execute(
            sa.text(
                "UPDATE lesson_bookings SET booking_id = :owner "
                "WHERE lesson_id = :lesson AND booking_id = :booking",
            ),
            {
                "owner": booking_of.get(first, booking_id),
                "lesson": lesson_id,
                "booking": booking_id,
            },
        )

        if len(pieces) == 1:
            continue

        # The lesson keeps its first slice and its notes; the rest follow it.
        connection.execute(
            sa.text("UPDATE lessons SET end_time = :end WHERE id = :lesson"),
            {"end": end, "lesson": lesson_id},
        )
        connection.execute(
            sa.text(
                "DELETE FROM lesson_disciplines "
                "WHERE lesson_id = :lesson AND association_subject_id <> :subject",
            ),
            {"lesson": lesson_id, "subject": first},
        )

        for discipline, start, end in pieces[1:]:
            piece = connection.scalar(
                sa.text(
                    "INSERT INTO lessons (availability_id, date, teacher_mode, "
                    "mode, start_time, end_time, created_at, updated_at) "
                    "SELECT availability_id, date, teacher_mode, mode, :start, "
                    ":end, created_at, updated_at FROM lessons WHERE id = :lesson "
                    "RETURNING id",
                ),
                {"start": start, "end": end, "lesson": lesson_id},
            )
            connection.execute(
                sa.text(
                    "INSERT INTO lesson_disciplines (lesson_id, association_subject_id) "
                    "VALUES (:piece, :subject)",
                ),
                {"piece": piece, "subject": discipline},
            )
            connection.execute(
                sa.text(
                    "INSERT INTO lesson_bookings (lesson_id, booking_id) "
                    "VALUES (:piece, :owner)",
                ),
                {"piece": piece, "owner": booking_of[discipline]},
            )


def upgrade() -> None:
    _replace_check(
        "bookings",
        "booking_duration_step",
        "duration BETWEEN 15 AND 120 AND duration % 15 = 0",
    )
    _replace_check(
        "lessons",
        "lesson_minimum_duration",
        "end_time - start_time >= INTERVAL '15 minutes'",
    )

    connection = op.get_bind()

    rows = connection.execute(
        sa.text(
            "SELECT b.id, b.duration, s.id FROM bookings b "
            "JOIN subjects_requested r ON r.booking_id = b.id "
            "JOIN association_subjects s ON s.id = r.association_subject_id "
            "WHERE b.id IN (SELECT booking_id FROM subjects_requested "
            "GROUP BY booking_id HAVING count(*) > 1) "
            "ORDER BY b.id, s.name, s.id",
        ),
    ).all()

    disciplines: dict[tuple[int, int], list[int]] = defaultdict(list)

    for booking_id, duration, discipline in rows:
        disciplines[(booking_id, duration)].append(discipline)

    unsplittable = []

    for (booking_id, duration), order in disciplines.items():
        try:
            _split_booking(connection, booking_id, duration, order)
        except _Unsplittable:
            unsplittable.append(booking_id)

    # Rare enough to settle by hand.
    if unsplittable:
        raise RuntimeError(
            "Bookings that cannot be split in equal parts: "
            f"{', '.join(str(booking_id) for booking_id in unsplittable)}",
        )

    op.create_unique_constraint(
        op.f("uq_subjects_requested_booking_id"),
        "subjects_requested",
        ["booking_id"],
        deferrable=True,
        initially="DEFERRED",
    )


# Split bookings stay split.
# Fails while a booking or lesson is shorter than half an hour.
def downgrade() -> None:
    op.drop_constraint(
        op.f("uq_subjects_requested_booking_id"),
        "subjects_requested",
        type_="unique",
    )
    _replace_check(
        "lessons",
        "lesson_minimum_duration",
        "end_time - start_time >= INTERVAL '30 minutes'",
    )
    _replace_check(
        "bookings",
        "booking_duration_step",
        "duration BETWEEN 30 AND 120 AND duration % 15 = 0",
    )

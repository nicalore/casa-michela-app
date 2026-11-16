from collections import defaultdict
from collections.abc import Collection, Iterable, Sequence
from dataclasses import dataclass
from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.membership import Membership, MembershipRevocationEnum

# Half-open [first, after); a renewal before the lapse carries the run on.
EnrolledSpan = tuple[date, date]


def _runs(spans: list[EnrolledSpan]) -> list[EnrolledSpan]:
    runs: list[EnrolledSpan] = []

    for first, after in sorted(spans):
        if runs and runs[-1][1] >= first:
            runs[-1] = (runs[-1][0], max(runs[-1][1], after))
        else:
            runs.append((first, after))

    return runs


@dataclass(frozen=True)
class YearRow:
    year: int
    start_date: date
    end_date: date
    renewal_period_days: int


# Each year until its lapse, cut short by a newer start; years left empty are absent.
def year_spans(rows: Iterable[YearRow]) -> dict[int, EnrolledSpan]:
    spans: dict[int, EnrolledSpan] = {}
    newer_start: date | None = None

    for row in sorted(rows, key=lambda item: item.year, reverse=True):
        after = row.end_date + timedelta(days=row.renewal_period_days)

        if newer_start is not None:
            after = min(after, newer_start)

        if row.start_date < after:
            spans[row.year] = (row.start_date, after)

        newer_start = (
            row.start_date if newer_start is None else min(row.start_date, newer_start)
        )

    return spans


def spans_of(rows: Iterable[YearRow]) -> list[EnrolledSpan]:
    return _runs(list(year_spans(rows).values()))


# statistics._enrolled_on as spans: until the lapse, a newer start or a revocation.
async def enrolled_spans(
    db: AsyncSession,
    tax_codes: Collection[str],
) -> dict[str, list[EnrolledSpan]]:
    if not tax_codes:
        return {}

    rows = await db.execute(
        select(
            Membership.member_tax_code,
            Membership.year,
            Membership.start_date,
            Membership.end_date,
            Membership.renewal_period_days,
        ).where(Membership.member_tax_code.in_(tax_codes)),
    )

    by_member: dict[str, list[YearRow]] = defaultdict(list)

    for tax_code, year, start, end, renewal_days in rows.tuples():
        by_member[tax_code].append(YearRow(year, start, end, renewal_days))

    spans = {tax_code: spans_of(listed) for tax_code, listed in by_member.items()}

    return {tax_code: runs for tax_code, runs in spans.items() if runs}


def is_enrolled_on(day: date, spans: Sequence[EnrolledSpan]) -> bool:
    return any(first <= day < after for first, after in spans)


# The day one enrolled on within [start, end), if any.
def enrollment_within(
    spans: Sequence[EnrolledSpan],
    start: date,
    end: date,
) -> date | None:
    return max((first for first, _ in spans if start <= first < end), default=None)


def enrolled_days(spans: Sequence[EnrolledSpan], start: date, end: date) -> int:
    return sum(
        max((min(after, end) - max(first, start)).days, 0) for first, after in spans
    )


def enrolled_throughout(spans: Sequence[EnrolledSpan], start: date, end: date) -> bool:
    return enrolled_days(spans, start, end) == max((end - start).days, 0)


# What is left of [spans] once [removed] is taken out of it.
def without(
    spans: Sequence[EnrolledSpan],
    removed: Sequence[EnrolledSpan],
) -> list[EnrolledSpan]:
    left = list(spans)

    for cut_first, cut_after in removed:
        left = [
            piece
            for first, after in left
            for piece in (
                (first, min(after, cut_first)),
                (max(first, cut_after), after),
            )
            if piece[0] < piece[1]
        ]

    return sorted(left)


def first_shared_day(
    spans: Sequence[EnrolledSpan],
    others: Sequence[EnrolledSpan],
) -> date | None:
    return min(
        (
            max(first, other_first)
            for first, after in spans
            for other_first, other_after in others
            if max(first, other_first) < min(after, other_after)
        ),
        default=None,
    )


# As hours read them: the day of a revocation still counts, since its hours were
# done before it.
async def hours_spans(
    db: AsyncSession,
    tax_codes: Collection[str],
) -> dict[str, list[EnrolledSpan]]:
    if not tax_codes:
        return {}

    rows = await db.execute(
        select(
            Membership.member_tax_code,
            Membership.year,
            Membership.start_date,
            Membership.end_date,
            Membership.renewal_period_days,
            Membership.revocation,
        ).where(Membership.member_tax_code.in_(tax_codes)),
    )

    by_member: dict[str, list[YearRow]] = defaultdict(list)

    for tax_code, year, start, end, renewal_days, revocation in rows.tuples():
        revoked = revocation != MembershipRevocationEnum.NO
        last = end + timedelta(days=1) if revoked else end
        by_member[tax_code].append(YearRow(year, start, last, renewal_days))

    spans = {tax_code: spans_of(listed) for tax_code, listed in by_member.items()}

    return {tax_code: runs for tax_code, runs in spans.items() if runs}


# Who among tax_codes has hours on day.
async def enrolled_on(
    db: AsyncSession,
    tax_codes: Collection[str],
    day: date,
) -> set[str]:
    spans = await hours_spans(db, tax_codes)

    return {
        tax_code
        for tax_code, member_spans in spans.items()
        if is_enrolled_on(day, member_spans)
    }

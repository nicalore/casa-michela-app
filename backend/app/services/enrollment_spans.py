from collections import defaultdict
from collections.abc import Collection, Sequence
from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.membership import Membership

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
            Membership.start_date,
            Membership.end_date,
            Membership.renewal_period_days,
        )
        .where(Membership.member_tax_code.in_(tax_codes))
        .order_by(Membership.member_tax_code, Membership.year.desc()),
    )

    spans: dict[str, list[EnrolledSpan]] = defaultdict(list)
    newer_start: dict[str, date] = {}

    for tax_code, start, end, renewal_days in rows:
        after = end + timedelta(days=renewal_days)

        if tax_code in newer_start:
            after = min(after, newer_start[tax_code])

        if start < after:
            spans[tax_code].append((start, after))

        newer_start[tax_code] = min(start, newer_start.get(tax_code, start))

    return {tax_code: _runs(member_spans) for tax_code, member_spans in spans.items()}


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

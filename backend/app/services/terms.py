from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.account import Account
from app.models.terms import TermsAcceptance, TermsRequest


async def latest_terms_request(db: AsyncSession) -> datetime | None:
    return await db.scalar(select(func.max(TermsRequest.requested_at)))


def _accepted_since(account: Account, requested_at: datetime | None) -> bool:
    accepted_at = account.terms_accepted_at

    if accepted_at is None:
        return False

    return requested_at is None or accepted_at >= requested_at


def terms_due(account: Account, requested_at: datetime | None) -> bool:
    return settings.terms_acceptance_enabled and not _accepted_since(
        account,
        requested_at,
    )


# Only for whoever had accepted before: the others walk the first access.
def terms_update_shown(
    account: Account,
    requested_at: datetime | None,
) -> datetime | None:
    if account.terms_accepted_at is None or not terms_due(account, requested_at):
        return None

    return requested_at


# An acceptance still current stays as it is, with no new row.
def record_terms_acceptance(
    db: AsyncSession,
    account: Account,
    requested_at: datetime | None,
) -> None:
    if _accepted_since(account, requested_at):
        return

    now = datetime.now(UTC)
    account.terms_accepted_at = now
    db.add(TermsAcceptance(account_tax_code=account.tax_code, accepted_at=now))


def request_terms(db: AsyncSession, author_tax_code: str) -> TermsRequest:
    request = TermsRequest(
        requested_at=datetime.now(UTC),
        author_tax_code=author_tax_code,
    )
    db.add(request)

    return request

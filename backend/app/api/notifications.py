from collections.abc import Sequence
from datetime import date
from typing import Annotated, Final

from fastapi import (
    APIRouter,
    BackgroundTasks,
    HTTPException,
    Query,
    Response,
    status,
)
from sqlalchemy import func, or_, select

from app.api.current_account import CurrentAccount, CurrentSessionId
from app.api.dependencies import DbSession
from app.api.rbac import CurrentIdentity
from app.core.time_band import TimeBandEnum
from app.models.notice import Notice, NoticeRoleEnum
from app.models.notification import Notification, NotificationKindEnum
from app.schemas.notification import NotificationKindChoice, NotificationResponse
from app.services import push
from app.services.availability_notifications import availabilities_seen
from app.services.booking_notifications import bookings_seen
from app.services.new_devices import about_session
from app.services.notice_notifications import reached_roles
from app.services.notification_kinds import choices_of, choose
from app.services.notifications import dismissals, withdraw

_NOTIFICATION_NOT_FOUND_ERROR: Final[str] = "Notifica non trovata."

# Once read they have said all they had to: a new device's sign-in, and a rating
# reminder, whose reader is taken to the rating or chose to let it be.
_GONE_ONCE_READ: Final[frozenset[NotificationKindEnum]] = frozenset(
    {NotificationKindEnum.NEW_DEVICE, NotificationKindEnum.RATING_REMINDER},
)

router = APIRouter(prefix="/notifications", tags=["notifications"])


# Whom each notice announced was sent to, by role.
async def _notice_recipients(
    db: DbSession,
    rows: Sequence[Notification],
) -> dict[int, list[NoticeRoleEnum]]:
    ids = {row.notice_id for row in rows if row.notice_id is not None}

    if not ids:
        return {}

    pairs = await db.execute(
        select(Notice.id, Notice.recipients).where(Notice.id.in_(ids))
    )

    return dict(pairs.tuples().all())


# Newest first: the home card shows them all, until withdrawn or expired.
@router.get("")
async def my_notifications(
    current_account: CurrentAccount,
    identity: CurrentIdentity,
    current_session_id: CurrentSessionId,
    db: DbSession,
) -> list[NotificationResponse]:
    notifications = await db.scalars(
        select(Notification)
        .where(
            Notification.account_tax_code == current_account.tax_code,
            Notification.withdrawn_at.is_(None),
            or_(
                Notification.expires_at.is_(None),
                Notification.expires_at > func.now(),
            ),
        )
        .order_by(Notification.created_at.desc(), Notification.id.desc())
    )
    rows = [
        row for row in notifications if not about_session(row, current_session_id)
    ]
    recipients = await _notice_recipients(db, rows)

    return [
        NotificationResponse.model_validate(row).model_copy(
            update={
                "notice_roles": reached_roles(
                    identity.roles,
                    recipients.get(row.notice_id or 0, ()),
                ),
            },
        )
        for row in rows
    ]


# Read means seen: it leaves the tray of every device it reached.
@router.put("/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_read(
    notification_id: int,
    current_account: CurrentAccount,
    db: DbSession,
    background: BackgroundTasks,
) -> Response:
    notification = await db.scalar(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.account_tax_code == current_account.tax_code,
        )
    )

    if notification is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_NOTIFICATION_NOT_FOUND_ERROR,
        )

    if notification.read_at is None:
        notification.read_at = func.now()

        if notification.kind in _GONE_ONCE_READ:
            notification.withdrawn_at = func.now()

        batch = await dismissals(db, [notification])
        await db.commit()
        background.add_task(push.deliver, batch)

    return Response(status_code=status.HTTP_204_NO_CONTENT)


# The kinds of the account's roles; the choice holds on every device.
@router.get("/kinds")
async def my_notification_kinds(
    current_account: CurrentAccount,
    db: DbSession,
) -> list[NotificationKindChoice]:
    return [
        NotificationKindChoice(kind=kind, enabled=enabled)
        for kind, enabled in await choices_of(db, current_account)
    ]


@router.put("/kinds")
async def choose_notification_kinds(
    choices: list[NotificationKindChoice],
    current_account: CurrentAccount,
    db: DbSession,
) -> list[NotificationKindChoice]:
    await choose(
        db,
        current_account,
        {choice.kind: choice.enabled for choice in choices},
    )
    await db.commit()

    return await my_notification_kinds(current_account, db)


# The calendar of that band on screen: what announced it has done its work.
@router.put(
    "/calendar/{calendar_date}/{band}/seen",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def calendar_seen(
    calendar_date: date,
    band: TimeBandEnum,
    current_account: CurrentAccount,
    db: DbSession,
    background: BackgroundTasks,
) -> Response:
    batch = await withdraw(
        db,
        kinds=[
            NotificationKindEnum.CALENDAR_PUBLISHED,
            NotificationKindEnum.CONVOCATION,
        ],
        calendar=(calendar_date, band),
        owners=[current_account.tax_code],
    )
    await db.commit()
    background.add_task(push.deliver, batch)

    return Response(status_code=status.HTTP_204_NO_CONTENT)


# That pupil's bookings of those days on screen: what announced them has done its work.
@router.put("/bookings/{pupil_tax_code}/seen", status_code=status.HTTP_204_NO_CONTENT)
async def pupil_bookings_seen(
    pupil_tax_code: str,
    date_from: Annotated[date, Query()],
    date_to: Annotated[date, Query()],
    current_account: CurrentAccount,
    db: DbSession,
    background: BackgroundTasks,
) -> Response:
    batch = await bookings_seen(
        db,
        current_account.tax_code,
        pupil_tax_code,
        date_from,
        date_to,
    )
    await db.commit()
    background.add_task(push.deliver, batch)

    return Response(status_code=status.HTTP_204_NO_CONTENT)


# One's own availabilities of those days on screen: what announced them is seen.
@router.put("/availabilities/seen", status_code=status.HTTP_204_NO_CONTENT)
async def own_availabilities_seen(
    date_from: Annotated[date, Query()],
    date_to: Annotated[date, Query()],
    current_account: CurrentAccount,
    db: DbSession,
    background: BackgroundTasks,
) -> Response:
    batch = await availabilities_seen(db, current_account.tax_code, date_from, date_to)
    await db.commit()
    background.add_task(push.deliver, batch)

    return Response(status_code=status.HTTP_204_NO_CONTENT)

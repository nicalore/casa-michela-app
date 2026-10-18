import logging
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime
from typing import Final

import aiohttp
from py_vapid import Vapid
from pywebpush import WebPushException, webpush_async
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.session import AsyncSessionLocal
from app.models.push_device import PushDevice
from app.repositories.refresh_token_repository import live_session
from app.services import fcm
from app.services.fcm import AppDismissal, AppPush

logger = logging.getLogger("push")

# Past a day the news is stale: the home card already shows it.
_TIME_TO_LIVE_SECONDS: Final[int] = 24 * 60 * 60

_TIMEOUT_SECONDS: Final[float] = 10

# How a push service says a subscription will never take another message.
_GONE: Final[frozenset[int]] = frozenset({404, 410})


@dataclass(frozen=True)
class WebPush:
    address: str
    p256dh: str
    auth: str
    payload: str


# Pushes to browsers through their services, to Android through FCM.
@dataclass(frozen=True)
class PushBatch:
    web: list[WebPush]
    android: list[AppPush | AppDismissal]


def joined(batches: Sequence[PushBatch]) -> PushBatch:
    return PushBatch(
        web=[push for batch in batches for push in batch.web],
        android=[push for batch in batches for push in batch.android],
    )


def web_push_enabled() -> bool:
    return bool(settings.vapid_public_key and settings.vapid_private_key)


# Sends every push; returns the addresses the push services gave up on.
async def send(pushes: Sequence[WebPush]) -> list[str]:
    if not pushes:
        return []

    if not web_push_enabled():
        logger.warning("Web push is not configured: %d pushes dropped", len(pushes))
        return []

    signer = Vapid.from_string(settings.vapid_private_key)

    async with aiohttp.ClientSession() as session:
        sent = [await _send_one(session, signer, push) for push in pushes]

    return [push.address for push, kept in zip(pushes, sent, strict=True) if not kept]


async def _send_one(
    session: aiohttp.ClientSession,
    signer: Vapid,
    push: WebPush,
) -> bool:
    try:
        await webpush_async(
            subscription_info={
                "endpoint": push.address,
                "keys": {"p256dh": push.p256dh, "auth": push.auth},
            },
            data=push.payload,
            vapid_private_key=signer,
            # pywebpush writes the endpoint's audience into it: one dict per push.
            vapid_claims={"sub": settings.vapid_subject},
            ttl=_TIME_TO_LIVE_SECONDS,
            timeout=_TIMEOUT_SECONDS,
            aiohttp_session=session,
        )
    except WebPushException as error:
        if error.status_code in _GONE:
            return False

        logger.warning("Web push refused (%s)", error.status_code)
    except (aiohttp.ClientError, TimeoutError):
        logger.exception("Web push could not reach its service")

    return True


async def forget(db: AsyncSession, addresses: Sequence[str]) -> None:
    if addresses:
        await db.execute(delete(PushDevice).where(PushDevice.address.in_(addresses)))
        await db.commit()


# Signed out, blocked or expired: the device goes with its session.
async def forget_ended_sessions(db: AsyncSession, now: datetime) -> None:
    await db.execute(
        delete(PushDevice).where(
            ~live_session(PushDevice.account_tax_code, PushDevice.session_id, now)
        )
    )
    await db.commit()


# Every push of the batch; returns the addresses given up on, browsers' and apps' alike.
async def send_batch(batch: PushBatch) -> list[str]:
    return [*await send(batch.web), *await fcm.send(batch.android)]


# Runs after the request: the request's session is closed by then.
async def deliver(batch: PushBatch) -> None:
    gone = await send_batch(batch)

    if gone:
        async with AsyncSessionLocal() as db:
            await forget(db, gone)

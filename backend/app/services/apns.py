import logging
import time
from collections.abc import Sequence
from functools import lru_cache
from pathlib import Path
from typing import Final

import httpx
import jwt

from app.core.config import settings
from app.services.fcm import AppDismissal, AppPush

logger = logging.getLogger("push")

_PRODUCTION: Final[str] = "https://api.push.apple.com"
_SANDBOX: Final[str] = "https://api.sandbox.push.apple.com"

# Apple takes a token for an hour and refuses one renewed more than every 20 minutes.
_TOKEN_LIFETIME_SECONDS: Final[int] = 45 * 60

_TIMEOUT: Final[httpx.Timeout] = httpx.Timeout(10)

# Past a day the news is stale: the home card already shows it.
_TIME_TO_LIVE_SECONDS: Final[int] = 24 * 60 * 60

# How Apple says a token belongs to no install of this app any more.
_GONE_REASONS: Final[frozenset[str]] = frozenset(
    {"Unregistered", "DeviceTokenNotForTopic"},
)

# Also what a development build's token gets from production, and the other way round.
_BAD_TOKEN: Final[str] = "BadDeviceToken"

_provider: tuple[str, float] | None = None

# Tokens of development builds, tried on the sandbox first after the first answer.
_sandbox_tokens: set[str] = set()


def apns_enabled() -> bool:
    path = settings.apns_key_path

    return bool(
        settings.apns_team_id
        and settings.apns_key_id
        and path is not None
        and path.is_file()
    )


@lru_cache(maxsize=1)
def _key(path: Path) -> str:
    return path.read_text()


def _provider_token(path: Path) -> str:
    global _provider

    now = time.time()

    if _provider is not None and _provider[1] > now:
        return _provider[0]

    token = jwt.encode(
        {"iss": settings.apns_team_id, "iat": int(now)},
        _key(path),
        algorithm="ES256",
        headers={"kid": settings.apns_key_id},
    )
    _provider = (token, now + _TOKEN_LIFETIME_SECONDS)

    return token


# Shown by the system; the collapse id lets a later push replace it.
def request_of(
    push: AppPush | AppDismissal,
) -> tuple[dict[str, str], dict[str, object]]:
    headers = {
        "apns-topic": settings.apns_topic,
        "apns-expiration": str(int(time.time()) + _TIME_TO_LIVE_SECONDS),
    }

    if isinstance(push, AppDismissal):
        return _dismissal_of(push, headers)

    return (
        {
            **headers,
            "apns-push-type": "alert",
            "apns-priority": "10",
            "apns-collapse-id": f"notification-{push.id}",
        },
        {
            "aps": {
                "alert": {"title": push.title, "body": push.body},
                "sound": "default",
            },
            "id": push.id,
            "kind": push.kind,
        },
    )


# Silent and low priority: Apple holds back urgent pushes that show nothing.
def _dismissal_of(
    push: AppDismissal,
    headers: dict[str, str],
) -> tuple[dict[str, str], dict[str, object]]:
    return (
        {**headers, "apns-push-type": "background", "apns-priority": "5"},
        {"aps": {"content-available": 1}, "type": "dismiss", "id": push.id},
    )


def _reason(response: httpx.Response) -> str:
    try:
        answer = response.json()
    except ValueError:
        return ""

    return str(answer.get("reason", "")) if isinstance(answer, dict) else ""


# False once Apple gave up on the token in both environments.
async def _send_one(
    client: httpx.AsyncClient,
    path: Path,
    push: AppPush | AppDismissal,
) -> bool:
    headers, body = request_of(push)
    headers["authorization"] = f"bearer {_provider_token(path)}"
    hosts = (_PRODUCTION, _SANDBOX)

    if push.token in _sandbox_tokens:
        hosts = (_SANDBOX, _PRODUCTION)

    for host in hosts:
        response = await client.post(
            f"{host}/3/device/{push.token}",
            json=body,
            headers=headers,
        )

        if response.status_code == 200:
            if host == _SANDBOX:
                _sandbox_tokens.add(push.token)

            return True

        reason = _reason(response)

        if response.status_code == 410 or reason in _GONE_REASONS:
            return False

        if reason != _BAD_TOKEN:
            logger.warning("APNs refused a push (%s %s)", response.status_code, reason)

            return True

    return False


# Sends every push; returns the tokens Apple gave up on.
async def send(pushes: Sequence[AppPush | AppDismissal]) -> list[str]:
    if not pushes:
        return []

    path = settings.apns_key_path

    if path is None or not apns_enabled():
        logger.warning("APNs is not configured: %d pushes dropped", len(pushes))
        return []

    gone: list[str] = []

    try:
        async with httpx.AsyncClient(http2=True, timeout=_TIMEOUT) as client:
            for push in pushes:
                if not await _send_one(client, path, push):
                    gone.append(push.token)
    except httpx.HTTPError:
        logger.exception("APNs could not be reached")

    return gone

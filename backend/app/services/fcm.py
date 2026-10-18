import json
import logging
import time
from collections.abc import Sequence
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Final

import aiohttp
import jwt

from app.core.config import settings

logger = logging.getLogger("push")

_SCOPE: Final[str] = "https://www.googleapis.com/auth/firebase.messaging"
_SEND_URL: Final[str] = "https://fcm.googleapis.com/v1/projects/{project}/messages:send"

# Google's access tokens last an hour; one is renewed this long before it ends.
_TOKEN_MARGIN_SECONDS: Final[int] = 300

_TIMEOUT: Final[aiohttp.ClientTimeout] = aiohttp.ClientTimeout(total=10)

# Past a day the news is stale: the home card already shows it.
_TIME_TO_LIVE: Final[str] = "86400s"


@dataclass(frozen=True)
class AppPush:
    token: str
    id: int
    kind: str
    title: str
    body: str


# Takes a notification off the device's tray; data only, so the app does it.
@dataclass(frozen=True)
class AppDismissal:
    token: str
    id: int


@dataclass(frozen=True)
class _ServiceAccount:
    project_id: str
    client_email: str
    private_key: str
    token_uri: str


_access: tuple[str, float] | None = None


def fcm_enabled() -> bool:
    path = settings.fcm_credentials_path

    return path is not None and path.is_file()


@lru_cache(maxsize=1)
def _account(path: Path) -> _ServiceAccount:
    data = json.loads(path.read_text())

    return _ServiceAccount(
        project_id=data["project_id"],
        client_email=data["client_email"],
        private_key=data["private_key"],
        token_uri=data["token_uri"],
    )


async def _access_token(
    session: aiohttp.ClientSession,
    account: _ServiceAccount,
) -> str:
    global _access

    if _access is not None and _access[1] > time.time() + _TOKEN_MARGIN_SECONDS:
        return _access[0]

    now = int(time.time())
    assertion = jwt.encode(
        {
            "iss": account.client_email,
            "scope": _SCOPE,
            "aud": account.token_uri,
            "iat": now,
            "exp": now + 3600,
        },
        account.private_key,
        algorithm="RS256",
    )

    async with session.post(
        account.token_uri,
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        },
    ) as response:
        response.raise_for_status()
        granted = await response.json()

    _access = (granted["access_token"], now + int(granted.get("expires_in", 3600)))

    return _access[0]


# No image: the system already shows the app's own icon beside the text.
def message_of(push: AppPush | AppDismissal) -> dict[str, object]:
    if isinstance(push, AppDismissal):
        return _dismissal_of(push)

    return {
        "message": {
            "token": push.token,
            "notification": {"title": push.title, "body": push.body},
            "data": {"id": str(push.id), "kind": push.kind},
            "android": {
                "priority": "HIGH",
                "ttl": _TIME_TO_LIVE,
                "notification": {"tag": f"notification-{push.id}"},
            },
        }
    }


# Normal priority: FCM demotes high ones that show nothing, and this one can wait.
def _dismissal_of(push: AppDismissal) -> dict[str, object]:
    return {
        "message": {
            "token": push.token,
            "data": {"type": "dismiss", "id": str(push.id)},
            "android": {"priority": "NORMAL", "ttl": _TIME_TO_LIVE},
        }
    }


# How FCM says a token belongs to no install any more.
def _is_gone(status: int, answer: dict[str, object]) -> bool:
    if status == 404:
        return True

    error = answer.get("error")
    details = error.get("details", []) if isinstance(error, dict) else []

    return any(
        isinstance(detail, dict) and detail.get("errorCode") == "UNREGISTERED"
        for detail in details
    )


async def _send_one(
    session: aiohttp.ClientSession,
    url: str,
    access: str,
    push: AppPush | AppDismissal,
) -> bool:
    async with session.post(
        url,
        json=message_of(push),
        headers={"Authorization": f"Bearer {access}"},
    ) as response:
        if response.status == 200:
            return True

        try:
            answer = await response.json(content_type=None)
        except ValueError:
            answer = {}

        if _is_gone(response.status, answer if isinstance(answer, dict) else {}):
            return False

        logger.warning("FCM refused a push (%s)", response.status)

        return True


# Sends every push; returns the tokens FCM gave up on.
async def send(pushes: Sequence[AppPush | AppDismissal]) -> list[str]:
    if not pushes:
        return []

    path = settings.fcm_credentials_path

    if path is None or not path.is_file():
        logger.warning("FCM is not configured: %d pushes dropped", len(pushes))
        return []

    account = _account(path)
    url = _SEND_URL.format(project=account.project_id)
    gone: list[str] = []

    try:
        async with aiohttp.ClientSession(timeout=_TIMEOUT) as session:
            access = await _access_token(session, account)

            for push in pushes:
                if not await _send_one(session, url, access, push):
                    gone.append(push.token)
    except (aiohttp.ClientError, TimeoutError):
        logger.exception("FCM could not be reached")

    return gone

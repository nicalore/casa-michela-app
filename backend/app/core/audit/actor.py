from typing import Any, Final

import jwt
from fastapi import Request

from app.core.audit.rules import ActorSource, AuditActor, AuditRule
from app.db.session import AsyncSessionLocal
from app.repositories.account_repository import AccountRepository

ANONYMOUS_ACTOR: Final[str] = "anonymous"

# Key under which the endpoint dependencies publish the resolved identity.
AUDIT_ACTOR_KEY: Final[str] = "audit_actor"

_BEARER_PREFIX: Final[str] = "Bearer "


# The signature is deliberately not verified: the payload is only used to label
# audit entries, never to grant access.
def _decode_unverified(token: str) -> dict[str, Any]:
    return jwt.decode(token, options={"verify_signature": False})


def _bearer_token(request: Request) -> str | None:
    authorization = request.headers.get("Authorization")

    if not authorization or not authorization.startswith(_BEARER_PREFIX):
        return None

    return authorization.removeprefix(_BEARER_PREFIX)


def _token_subject(token: str | None) -> str | None:
    if not token:
        return None

    try:
        return str(_decode_unverified(token).get("sub", "")) or None

    except Exception:
        return None


def state_actor(request: Request) -> AuditActor | None:
    return request.scope.get("state", {}).get(AUDIT_ACTOR_KEY)


# Its own session: the request transaction may already have been rolled back.
async def _tax_code_by_username(username: str) -> str:
    try:
        async with AsyncSessionLocal() as session:
            account = await AccountRepository(session).get_by_username(username)

            return account.tax_code if account else username

    except Exception:
        return username


async def _actor_from_body(
    source: ActorSource,
    payload: dict[str, Any],
) -> str | None:
    if source is ActorSource.BODY_USERNAME:
        username = payload.get("username")

        return await _tax_code_by_username(username) if username else None

    if source is ActorSource.BODY_REFRESH_TOKEN:
        return _token_subject(payload.get("refresh_token"))

    return _token_subject(payload.get("token"))


async def resolve_actor(
    request: Request,
    rule: AuditRule,
    payload: dict[str, Any],
) -> str:
    # Preferred over the token: the endpoint verified this one.
    actor = state_actor(request)

    if actor is not None:
        return actor.tax_code

    subject = _token_subject(_bearer_token(request))

    if subject:
        return subject

    if rule.actor_fallback is not None and payload:
        from_body = await _actor_from_body(rule.actor_fallback, payload)

        if from_body:
            return from_body

    return ANONYMOUS_ACTOR


def resolve_role(request: Request) -> str:
    actor = state_actor(request)

    return actor.role if actor else ""

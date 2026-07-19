import asyncio
from datetime import UTC, datetime, timedelta
from hashlib import sha256
from typing import Any, Final

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from app.core.config import settings

_ACCESS_TOKEN_TYPE: Final[str] = "access"
_REFRESH_TOKEN_TYPE: Final[str] = "refresh"

_INVALID_TOKEN_TYPE_ERROR: Final[str] = "Tipo di token non valido"

password_hasher = PasswordHasher(
    time_cost=3,
    memory_cost=12288,
    parallelism=1,
    hash_len=32,
    salt_len=16,
)


def hash_password(password: str) -> str:
    return password_hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return password_hasher.verify(password_hash, password)

    except (VerifyMismatchError, InvalidHashError):
        return False


# Argon2 hashing is CPU-bound and deliberately slow: calling it directly
# inside a coroutine blocks the event loop and serializes concurrent
# logins.
async def hash_password_async(password: str) -> str:
    return await asyncio.to_thread(hash_password, password)


async def verify_password_async(password: str, password_hash: str) -> bool:
    return await asyncio.to_thread(verify_password, password, password_hash)


def _encode_token(
    claims: dict[str, Any],
    secret: str,
    expires_in: timedelta,
) -> str:
    payload = {**claims, "exp": datetime.now(UTC) + expires_in}

    return jwt.encode(
        payload,
        secret,
        algorithm=settings.jwt_algorithm,
    )


def create_access_token(subject: str, username: str) -> str:
    return _encode_token(
        {
            "sub": subject,
            "username": username,
            "type": _ACCESS_TOKEN_TYPE,
        },
        settings.jwt_access_secret,
        timedelta(minutes=settings.access_token_expire_minutes),
    )


def create_refresh_token(subject: str, username: str, token_id: str) -> str:
    return _encode_token(
        {
            "sub": subject,
            "username": username,
            "type": _REFRESH_TOKEN_TYPE,
            "jti": token_id,
        },
        settings.jwt_refresh_secret,
        timedelta(days=settings.refresh_token_expire_days),
    )


def _decode_token(token: str, secret: str, expected_type: str) -> dict[str, Any]:
    payload = jwt.decode(
        token,
        secret,
        algorithms=[settings.jwt_algorithm],
    )

    if payload["type"] != expected_type:
        raise ValueError(_INVALID_TOKEN_TYPE_ERROR)

    return payload


def decode_access_token(token: str) -> dict[str, Any]:
    return _decode_token(
        token,
        settings.jwt_access_secret,
        _ACCESS_TOKEN_TYPE,
    )


def decode_refresh_token(token: str) -> dict[str, Any]:
    return _decode_token(
        token,
        settings.jwt_refresh_secret,
        _REFRESH_TOKEN_TYPE,
    )


def hash_refresh_token(refresh_token: str) -> str:
    return sha256(refresh_token.encode("utf-8")).hexdigest()
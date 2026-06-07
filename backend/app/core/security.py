from datetime import UTC, datetime, timedelta
from hashlib import sha256
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import (
    InvalidHashError,
    VerifyMismatchError,
)

from app.core.config import settings

password_hasher = PasswordHasher(
    time_cost=3,
    memory_cost=12288,
    parallelism=1,
    hash_len=32,
    salt_len=16,
)


def hash_password(password: str) -> str:
    return password_hasher.hash(password)


def verify_password(
    password: str,
    password_hash: str,
) -> bool:
    try:
        return password_hasher.verify(
            password_hash,
            password,
        )

    except (
        VerifyMismatchError,
        InvalidHashError,
    ):
        return False


def create_access_token(
    subject: str,
    username: str,
) -> str:
    expires_at = (
        datetime.now(UTC)
        + timedelta(
            minutes=settings.access_token_expire_minutes
        )
    )

    payload = {
        "sub": subject,
        "username": username,
        "type": "access",
        "exp": expires_at,
    }

    return jwt.encode(
        payload,
        settings.jwt_access_secret,
        algorithm=settings.jwt_algorithm,
    )


def create_refresh_token(
    subject: str,
    username: str,
    token_id: str,
) -> str:
    expires_at = (
        datetime.now(UTC)
        + timedelta(
            days=settings.refresh_token_expire_days
        )
    )

    payload = {
        "sub": subject,
        "username": username,
        "type": "refresh",
        "jti": token_id,
        "exp": expires_at,
    }

    return jwt.encode(
        payload,
        settings.jwt_refresh_secret,
        algorithm=settings.jwt_algorithm,
    )


def decode_access_token(
    token: str,
) -> dict[str, Any]:
    payload = jwt.decode(
        token,
        settings.jwt_access_secret,
        algorithms=[
            settings.jwt_algorithm
        ],
    )

    if payload["type"] != "access":
        raise ValueError(
            "Invalid token type"
        )

    return payload


def decode_refresh_token(
    token: str,
) -> dict[str, Any]:
    payload = jwt.decode(
        token,
        settings.jwt_refresh_secret,
        algorithms=[
            settings.jwt_algorithm
        ],
    )

    if payload["type"] != "refresh":
        raise ValueError(
            "Invalid token type"
        )

    return payload


def hash_refresh_token(
    refresh_token: str,
) -> str:
    return sha256(
        refresh_token.encode("utf-8")
    ).hexdigest()
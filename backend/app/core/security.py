import asyncio
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


# ==========================
# VARIANTI ASYNC (RNF-IAMPERF-03)
# ==========================
# argon2-cffi non offre un'API nativa asincrona: hash_password() e
# verify_password() sono funzioni sincrone e CPU-bound (l'hashing è
# deliberatamente lento, per resistere a bruteforce). Chiamate
# direttamente dentro una coroutine, bloccano l'intero event loop per
# tutta la loro durata: sotto login concorrenti, le richieste si
# serializzano invece di essere processate in parallelo (misurato nel
# load test TC-IAM-135: mediana di /auth/login raddoppiata da 470ms a
# 950ms con 100 utenti concorrenti).
#
# asyncio.to_thread delega l'esecuzione al thread pool di default di
# asyncio, liberando l'event loop nel frattempo. Usare SEMPRE queste
# varianti nel codice che gira dentro richieste FastAPI; le versioni
# sincrone restano per gli script standalone (create_user.py,
# load_test_accounts.py) dove non esiste concorrenza da proteggere.

async def hash_password_async(password: str) -> str:
    return await asyncio.to_thread(hash_password, password)


async def verify_password_async(password: str, password_hash: str) -> bool:
    return await asyncio.to_thread(verify_password, password, password_hash)


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
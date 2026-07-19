import json
import logging
import os
from collections.abc import Callable
from datetime import datetime
from typing import Any, Final
from zoneinfo import ZoneInfo

import jwt
from fastapi import Request, Response

from app.db.session import AsyncSessionLocal
from app.repositories.account_repository import AccountRepository

LOG_FILE_TEMPLATE: Final[str] = os.getenv("AUDIT_LOG_PATH", "./logs/audit_{date}.log")
LOG_DIR: Final[str] = os.path.dirname(LOG_FILE_TEMPLATE)

_ROME_TIMEZONE: Final[ZoneInfo] = ZoneInfo("Europe/Rome")

_ANONYMOUS_USER: Final[str] = "anonymous"

_ACCOUNT_LOCKED_STATUS: Final[int] = 423

_BODY_METHODS: Final[frozenset[str]] = frozenset({"POST", "PUT", "PATCH"})
_UPDATE_METHODS: Final[frozenset[str]] = frozenset({"PUT", "PATCH"})

_ENTITY_TYPES: Final[dict[str, str]] = {
    "/subjects": "Subject",
    "/schools": "School",
    "/study-programs": "Study program",
    "/teaching-offerings": "Teaching offering",
    "/association-subjects": "Association subject",
    "/ministry-subjects": "Ministry subject",
}

if LOG_DIR:
    os.makedirs(LOG_DIR, exist_ok=True)


class DateRotatingFileHandler(logging.FileHandler):
    def __init__(self, filename_template: str, *args: Any, **kwargs: Any) -> None:
        self.filename_template = filename_template
        super().__init__(self._get_filename(), *args, **kwargs)

    def _get_filename(self) -> str:
        date = datetime.now(_ROME_TIMEZONE).strftime("%Y-%m-%d")
        return self.filename_template.format(date=date)

    def emit(self, record: logging.LogRecord) -> None:
        new_filename = os.path.abspath(self._get_filename())

        if self.baseFilename != new_filename:
            self.close()
            self.baseFilename = new_filename
            self.stream = self._open()

        super().emit(record)


logger = logging.getLogger("audit")
logger.setLevel(logging.INFO)

file_handler = DateRotatingFileHandler(LOG_FILE_TEMPLATE, encoding="utf-8")
file_handler.setFormatter(logging.Formatter("%(message)s"))
logger.addHandler(file_handler)


def log_audit_operation(
    user_id: str,
    operation_type: str,
    status: str,
    target: str = "",
) -> None:
    timestamp = datetime.now(_ROME_TIMEZONE).isoformat(timespec="milliseconds")
    message = f"{timestamp}\t{user_id}\t{operation_type}\t{status}\t{target}"

    logger.info(message)


def _decode_unverified(token: str) -> dict[str, Any]:
    # The signature is deliberately not verified: the payload is only used to
    # label audit entries, never to grant access.
    return jwt.decode(token, options={"verify_signature": False})


def _extract_response_field(body: bytes, field: str) -> str:
    try:
        return str(json.loads(body).get(field, ""))

    except Exception:
        return ""


async def _resolve_tax_code_from_db(
    username: str | None = None,
    email: str | None = None,
) -> str:
    fallback = username or email or _ANONYMOUS_USER

    try:
        async with AsyncSessionLocal() as session:
            repository = AccountRepository(session)

            if username:
                account = await repository.get_by_username(username)
            elif email:
                account = await repository.get_by_email(email)
            else:
                account = None

            return account.tax_code if account else fallback

    except Exception:
        return fallback


async def extract_user_id(request: Request) -> str:
    authorization = request.headers.get("Authorization")

    if authorization and authorization.startswith("Bearer "):
        token = authorization.split(" ")[1]

        try:
            return str(_decode_unverified(token).get("sub", _ANONYMOUS_USER))

        except Exception:
            pass

    user_id = _ANONYMOUS_USER

    try:
        body = await request.body()

        if body:
            # Reading the body consumes the ASGI stream: re-inject it so that
            # the downstream handlers can still read the request payload.
            async def receive() -> dict[str, Any]:
                return {"type": "http.request", "body": body}

            request._receive = receive

            payload = json.loads(body)
            path = request.url.path

            if "/auth/login" in path:
                username = payload.get("username")

                if username:
                    user_id = await _resolve_tax_code_from_db(username=username)

            elif "/auth/logout" in path or "/auth/change-password" in path:
                refresh_token = payload.get("refresh_token")

                if refresh_token:
                    user_id = _decode_unverified(refresh_token).get(
                        "sub",
                        _ANONYMOUS_USER,
                    )

            elif "/auth/request-password-reset" in path:
                email = payload.get("email")

                if email:
                    user_id = await _resolve_tax_code_from_db(email=email)

            elif "/auth/reset-password" in path:
                reset_token = payload.get("token")

                if reset_token:
                    user_id = _decode_unverified(reset_token).get(
                        "sub",
                        _ANONYMOUS_USER,
                    )

    except Exception:
        pass

    return str(user_id)


async def audit_logging_middleware(request: Request, call_next: Callable) -> Response:
    if request.method == "OPTIONS":
        return await call_next(request)

    user_id = await extract_user_id(request)
    response = await call_next(request)

    path = request.url.path
    operation_type: str | None = None
    target = ""
    status = "Success" if response.status_code < 400 else "Failure"
    response_body = b""

    # The streaming body can be consumed only once: buffer it and rebuild the
    # response, otherwise the client would receive an empty payload.
    if status == "Success" and request.method in _BODY_METHODS:
        response_body = b"".join([section async for section in response.body_iterator])
        response = Response(
            content=response_body,
            status_code=response.status_code,
            headers=dict(response.headers),
            media_type=response.media_type,
        )

    if "/auth/login" in path:
        operation_type = "Authentication"

        if response.status_code == _ACCOUNT_LOCKED_STATUS:
            log_audit_operation(user_id, "Account Lockout", "System", target)
            status = "Failure"

    elif "/auth/logout" in path:
        operation_type = "Logout"

    elif "/auth/change-password" in path:
        operation_type = "Password Change"

    elif "/auth/request-password-reset" in path:
        operation_type = "Password Reset Request"

    elif "/auth/reset-password" in path:
        operation_type = "Password Reset"

    elif "/people" in path:
        if request.method == "POST":
            operation_type = "Person creation"

            if status == "Success":
                target = _extract_response_field(response_body, "tax_code")

        elif request.method in _UPDATE_METHODS:
            operation_type = "Person modification"
            parts = path.split("/")

            if len(parts) > 2:
                target = parts[2]

    else:
        entity_type = next(
            (name for prefix, name in _ENTITY_TYPES.items() if prefix in path),
            None,
        )

        if entity_type:
            if request.method == "POST":
                operation_type = f"{entity_type} creation"

                if status == "Success":
                    target = _extract_response_field(response_body, "id")

            elif request.method in _UPDATE_METHODS:
                operation_type = f"{entity_type} modification"
                target = path.split("/")[-1]

            elif request.method == "DELETE":
                operation_type = f"{entity_type} elimination"
                target = path.split("/")[-1]

    if operation_type:
        log_audit_operation(
            user_id=user_id,
            operation_type=operation_type,
            status=status,
            target=str(target),
        )

    return response
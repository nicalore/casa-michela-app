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
_BEARER_PREFIX: Final[str] = "Bearer "

_ACCOUNT_LOCKED_STATUS: Final[int] = 423

_SUCCESS_STATUS: Final[str] = "Success"
_FAILURE_STATUS: Final[str] = "Failure"

_BODY_METHODS: Final[frozenset[str]] = frozenset({"POST", "PUT", "PATCH"})
_UPDATE_METHODS: Final[frozenset[str]] = frozenset({"PUT", "PATCH"})

_ENROLLMENT_FORM_PATH: Final[str] = "/people/wizard/enrollment-form"

_LOGIN_PATH: Final[str] = "/auth/login"

_AUTH_OPERATIONS: Final[dict[str, str]] = {
    _LOGIN_PATH: "Authentication",
    "/auth/logout": "Logout",
    "/auth/change-password": "Password Change",
    "/auth/request-password-reset": "Password Reset Request",
    "/auth/reset-password": "Password Reset",
}

_ENTITY_TYPES: Final[dict[str, str]] = {
    "/subjects": "Subject",
    "/schools": "School",
    "/services": "Service",
    "/study-programs": "Study program",
    "/teaching-offerings": "Teaching offering",
    "/association-subjects": "Association subject",
    "/ministry-subjects": "Ministry subject",
    "/availabilities": "Availability",
    "/presences": "Presence",
    "/bookings": "Booking",
    "/lesson-requests": "Lesson request",
    "/opening-days": "Opening day",
    "/weekly-templates": "Weekly template",
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


def _match_by_path_fragment(path: str, values: dict[str, str]) -> str | None:
    return next(
        (value for fragment, value in values.items() if fragment in path),
        None,
    )


def _path_segment(path: str, index: int) -> str:
    segments = path.split("/")

    return segments[index] if len(segments) > index else ""


# The signature is deliberately not verified: the payload is only used to label
# audit entries, never to grant access.
def _decode_unverified(token: str) -> dict[str, Any]:
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


def _bearer_token(request: Request) -> str | None:
    authorization = request.headers.get("Authorization")

    if not authorization or not authorization.startswith(_BEARER_PREFIX):
        return None

    return authorization.split(" ")[1]


def _token_subject(token: str | None) -> str | None:
    if not token:
        return None

    return str(_decode_unverified(token).get("sub", _ANONYMOUS_USER))


# Reading the body consumes the ASGI stream: re-inject it so that the
# downstream handlers can still read the request payload.
def _reinject_body(request: Request, body: bytes) -> None:
    async def receive() -> dict[str, Any]:
        return {"type": "http.request", "body": body}

    request._receive = receive


async def _user_id_from_auth_payload(
    path: str,
    payload: dict[str, Any],
) -> str | None:
    if _LOGIN_PATH in path:
        username = payload.get("username")

        return await _resolve_tax_code_from_db(username=username) if username else None

    if "/auth/logout" in path or "/auth/change-password" in path:
        return _token_subject(payload.get("refresh_token"))

    if "/auth/request-password-reset" in path:
        email = payload.get("email")

        return await _resolve_tax_code_from_db(email=email) if email else None

    if "/auth/reset-password" in path:
        return _token_subject(payload.get("token"))

    return None


async def extract_user_id(request: Request) -> str:
    token = _bearer_token(request)

    if token:
        try:
            return str(_decode_unverified(token).get("sub", _ANONYMOUS_USER))

        except Exception:
            pass

    try:
        body = await request.body()

        if body:
            _reinject_body(request, body)

            user_id = await _user_id_from_auth_payload(
                request.url.path,
                json.loads(body),
            )

            if user_id is not None:
                return user_id

    except Exception:
        pass

    return _ANONYMOUS_USER


# The streaming body can be consumed only once: buffer it and rebuild the
# response, otherwise the client would receive an empty payload.
async def _buffer_response(response: Response) -> tuple[bytes, Response]:
    body = b"".join([section async for section in response.body_iterator])

    return body, Response(
        content=body,
        status_code=response.status_code,
        headers=dict(response.headers),
        media_type=response.media_type,
    )


def _resolve_people_operation(
    method: str,
    path: str,
    status: str,
    response_body: bytes,
) -> tuple[str | None, str]:
    # A generated form creates nobody, and its body is a PDF: without this it
    # would be logged as a person creation whose target could not be read.
    if _ENROLLMENT_FORM_PATH in path:
        return "Enrollment form generation", ""

    if method == "POST":
        target = (
            _extract_response_field(response_body, "tax_code")
            if status == _SUCCESS_STATUS
            else ""
        )

        return "Person creation", target

    if method in _UPDATE_METHODS:
        return "Person modification", _path_segment(path, 2)

    return None, ""


def _resolve_entity_operation(
    method: str,
    path: str,
    status: str,
    response_body: bytes,
) -> tuple[str | None, str]:
    entity_type = _match_by_path_fragment(path, _ENTITY_TYPES)

    if entity_type is None:
        return None, ""

    if method == "POST":
        target = (
            _extract_response_field(response_body, "id")
            if status == _SUCCESS_STATUS
            else ""
        )

        return f"{entity_type} creation", target

    if method in _UPDATE_METHODS:
        return f"{entity_type} modification", path.split("/")[-1]

    if method == "DELETE":
        return f"{entity_type} elimination", path.split("/")[-1]

    return None, ""


async def audit_logging_middleware(request: Request, call_next: Callable) -> Response:
    if request.method == "OPTIONS":
        return await call_next(request)

    user_id = await extract_user_id(request)
    response = await call_next(request)

    path = request.url.path
    status = _SUCCESS_STATUS if response.status_code < 400 else _FAILURE_STATUS
    response_body = b""

    if (
        status == _SUCCESS_STATUS
        and request.method in _BODY_METHODS
        and _ENROLLMENT_FORM_PATH not in path
    ):
        response_body, response = await _buffer_response(response)

    auth_operation = _match_by_path_fragment(path, _AUTH_OPERATIONS)
    target = ""

    if auth_operation is not None:
        operation_type: str | None = auth_operation

        if _LOGIN_PATH in path and response.status_code == _ACCOUNT_LOCKED_STATUS:
            log_audit_operation(user_id, "Account Lockout", "System", target)
            status = _FAILURE_STATUS

    elif "/people" in path:
        operation_type, target = _resolve_people_operation(
            request.method,
            path,
            status,
            response_body,
        )

    else:
        operation_type, target = _resolve_entity_operation(
            request.method,
            path,
            status,
            response_body,
        )

    if operation_type:
        log_audit_operation(
            user_id=user_id,
            operation_type=operation_type,
            status=status,
            target=str(target),
        )

    return response

from collections.abc import AsyncIterator, Callable
from typing import Any, Final

from fastapi import Request, Response

from app.core.audit import (
    AUDIT_RULES,
    FAILURE_OUTCOME,
    LOCKOUT_OPERATION,
    LOCKOUT_ROUTE,
    SUCCESS_OUTCOME,
    AuditEntry,
    AuditRule,
    audit_timestamp,
    decode_payload,
    log_audit_entry,
    resolve_actor,
    resolve_role,
    resolve_target,
)

_SKIPPED_METHODS: Final[frozenset[str]] = frozenset({"OPTIONS", "HEAD"})
_BODY_METHODS: Final[frozenset[str]] = frozenset({"POST", "PUT", "PATCH"})

_JSON_CONTENT_TYPE: Final[str] = "application/json"
_MAX_AUDITED_BODY_BYTES: Final[int] = 1_000_000

_ERROR_STATUS: Final[int] = 400
_INTERNAL_ERROR_STATUS: Final[int] = 500
_ACCOUNT_LOCKED_STATUS: Final[int] = 423


# Reading the body caches it on the request, and Starlette replays it to the
# handlers below. Skipped for uploads, which would only be buffered for nothing.
def _should_read_body(request: Request) -> bool:
    if request.method not in _BODY_METHODS:
        return False

    if not request.headers.get("content-type", "").startswith(_JSON_CONTENT_TYPE):
        return False

    return int(request.headers.get("content-length") or 0) <= _MAX_AUDITED_BODY_BYTES


async def _request_payload(request: Request) -> dict[str, Any]:
    if not _should_read_body(request):
        return {}

    try:
        return decode_payload(await request.body())

    except Exception:
        return {}


# Routing fills the scope before the endpoint runs, so the matched template is
# there even when the call ends in an exception.
def _matched_rule(request: Request) -> tuple[AuditRule | None, str]:
    route = request.scope.get("route")

    if route is None:
        return None, ""

    return AUDIT_RULES.get((request.method, route.path)), route.path


async def _replay(body: bytes) -> AsyncIterator[bytes]:
    yield body


# The streaming body can be consumed only once: put it back after reading it.
# Swapping the iterator leaves the response headers untouched.
async def _buffered_body(response: Response) -> bytes:
    body = b"".join([section async for section in response.body_iterator])
    response.body_iterator = _replay(body)

    return body


async def _record(
    request: Request,
    rule: AuditRule,
    operation: str,
    status_code: int,
    response_body: bytes,
    payload: dict[str, Any],
) -> None:
    log_audit_entry(
        AuditEntry(
            timestamp=audit_timestamp(),
            actor=await resolve_actor(request, rule, payload),
            role=resolve_role(request),
            operation=operation,
            outcome=(
                SUCCESS_OUTCOME if status_code < _ERROR_STATUS else FAILURE_OUTCOME
            ),
            status_code=status_code,
            target=resolve_target(
                rule,
                request.scope.get("path_params", {}),
                response_body,
                payload,
            ),
        )
    )


async def audit_logging_middleware(request: Request, call_next: Callable) -> Response:
    if request.method in _SKIPPED_METHODS:
        return await call_next(request)

    payload = await _request_payload(request)

    try:
        response = await call_next(request)

    except Exception:
        rule, _ = _matched_rule(request)

        if rule is not None:
            await _record(
                request,
                rule,
                rule.operation,
                _INTERNAL_ERROR_STATUS,
                b"",
                payload,
            )

        raise

    rule, path = _matched_rule(request)

    if rule is None:
        return response

    status_code = response.status_code
    response_body = b""

    if rule.response_field and status_code < _ERROR_STATUS:
        response_body = await _buffered_body(response)

    # A lockout is a decision of its own: the failed attempt that triggered it
    # is still logged on the line below.
    locked_out = status_code == _ACCOUNT_LOCKED_STATUS

    if locked_out and (request.method, path) == LOCKOUT_ROUTE:
        await _record(request, rule, LOCKOUT_OPERATION, status_code, b"", payload)

    await _record(request, rule, rule.operation, status_code, response_body, payload)

    return response

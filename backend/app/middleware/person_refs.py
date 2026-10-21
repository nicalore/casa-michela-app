from typing import Final

from starlette.datastructures import Headers, MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.person_refs import (
    KEPT_TAX_CODES_STATE_KEY,
    hide_tax_codes,
    name_by_reference,
    reveal_tax_codes,
)

_BODY_METHODS: Final[frozenset[str]] = frozenset({"POST", "PUT", "PATCH"})

_JSON_CONTENT_TYPE: Final[str] = "application/json"


def _is_json(headers: Headers) -> bool:
    return headers.get("content-type", "").startswith(_JSON_CONTENT_TYPE)


def _revealed(body: bytes, named: set[str]) -> bytes:
    try:
        return reveal_tax_codes(body.decode(), named).encode()

    except UnicodeDecodeError:
        return body


def _revealed_latin1(raw: bytes, named: set[str]) -> bytes:
    return reveal_tax_codes(raw.decode("latin-1"), named).encode("latin-1")


async def _revealed_receive(
    scope: Scope,
    receive: Receive,
    named: set[str],
) -> Receive:
    if scope["method"] not in _BODY_METHODS or not _is_json(Headers(scope=scope)):
        return receive

    chunks: list[bytes] = []
    pending: list[Message] = []

    while True:
        message = await receive()

        if message["type"] != "http.request":
            pending.append(message)
            break

        chunks.append(message.get("body", b""))

        if not message.get("more_body", False):
            break

    body = _revealed(b"".join(chunks), named)
    MutableHeaders(scope=scope)["content-length"] = str(len(body))
    pending.insert(0, {"type": "http.request", "body": body, "more_body": False})

    async def replay() -> Message:
        return pending.pop(0) if pending else await receive()

    return replay


# Requests name people by reference or tax code; only administrators read tax codes.
class PersonRefsMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        named: set[str] = set()

        # A copy: the server's access log keeps the references it was sent.
        scope = {**scope, "path": reveal_tax_codes(scope["path"], named)}
        state = scope.setdefault("state", {})

        for key in ("raw_path", "query_string"):
            if scope.get(key):
                scope[key] = _revealed_latin1(scope[key], named)

        receive = await _revealed_receive(scope, receive, named)
        name_by_reference(named)

        start: Message | None = None
        chunks: list[bytes] = []

        async def send_hidden(message: Message) -> None:
            nonlocal start

            if message["type"] == "http.response.start":
                hiding = state.get(KEPT_TAX_CODES_STATE_KEY) is not None

                if hiding and _is_json(Headers(raw=message["headers"])):
                    start = message
                    return

            if start is None or message["type"] != "http.response.body":
                await send(message)
                return

            chunks.append(message.get("body", b""))

            if message.get("more_body", False):
                return

            body = hide_tax_codes(
                b"".join(chunks).decode(),
                state[KEPT_TAX_CODES_STATE_KEY],
            ).encode()
            headers = MutableHeaders(raw=list(start["headers"]))
            headers["content-length"] = str(len(body))

            await send({**start, "headers": headers.raw})
            await send({"type": "http.response.body", "body": body})

        await self.app(scope, receive, send_hidden)

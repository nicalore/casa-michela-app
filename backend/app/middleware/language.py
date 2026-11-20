from starlette.datastructures import Headers
from starlette.types import ASGIApp, Receive, Scope, Send

from app.core.i18n import (
    forget_request_language,
    language_from_header,
    use_request_language,
)


# Reads Accept-Language once per request, for tr() in errors and responses.
class LanguageMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)

            return

        header = Headers(scope=scope).get("accept-language")
        token = use_request_language(language_from_header(header))

        try:
            await self.app(scope, receive, send)

        finally:
            forget_request_language(token)

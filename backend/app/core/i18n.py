from contextvars import ContextVar, Token
from typing import Final

ITALIAN: Final[str] = "it"
ENGLISH: Final[str] = "en"

# The language of the request being served; set by LanguageMiddleware.
_request_language: ContextVar[str] = ContextVar("request_language", default=ITALIAN)


# 'en', 'en-GB' or 'en-US,en;q=0.9' -> English; anything else or nothing -> Italian.
def language_from_header(value: str | None) -> str:
    if value and value.strip().lower().startswith(ENGLISH):
        return ENGLISH

    return ITALIAN


def request_language() -> str:
    return _request_language.get()


def use_request_language(language: str) -> Token[str]:
    return _request_language.set(language)


def forget_request_language(token: Token[str]) -> None:
    _request_language.reset(token)


# A text for whoever made the request, Italian first.
def tr(it: str, en: str) -> str:
    return tr_for(_request_language.get(), it, en)


# A text for a recipient (push, email) in their account's language; None -> Italian.
def tr_for(language: str | None, it: str, en: str) -> str:
    return en if language == ENGLISH else it

import re
from collections.abc import Callable, Iterator, Sequence
from typing import Final

from markdown_it import MarkdownIt
from markdown_it.token import Token

from app.services import email_service

IMAGE_SCHEME: Final[str] = "image:"

_IMAGE_KEY: Final[re.Pattern[str]] = re.compile(r"[0-9A-Za-z-]{1,36}")

_PREVIEW_LENGTH: Final[int] = 280

# Raw HTML is shown as text: what reaches an inbox is only what Markdown can say.
_MARKDOWN: Final[MarkdownIt] = MarkdownIt("commonmark", {"html": False}).enable(
    "strikethrough"
)

_BLOCK_GAP: Final[str] = "margin: 0 0 14px 0;"

# Set on every block: clients otherwise fall back to their own small size.
_TEXT: Final[str] = "font-size: 18px; line-height: 1.6;"


def _heading(size: int) -> str:
    return f"{_BLOCK_GAP} color: {email_service.INK}; font-size: {size}px;"


# Inline styles: email clients guarantee nothing more.
_STYLES: Final[dict[str, str]] = {
    "p": f"{_BLOCK_GAP} {_TEXT}",
    "ul": f"{_BLOCK_GAP} {_TEXT} padding-left: 22px;",
    "ol": f"{_BLOCK_GAP} {_TEXT} padding-left: 22px;",
    "li": f"margin: 0 0 4px 0; {_TEXT}",
    "h1": _heading(26),
    "h2": _heading(23),
    "h3": _heading(20),
    "blockquote": (
        f"{_BLOCK_GAP} {_TEXT} padding: 2px 0 2px 14px; "
        f"border-left: 3px solid {email_service.LINE}; color: {email_service.MUTED};"
    ),
    "a": f"color: {email_service.TEAL}; font-weight: 600;",
    # Already inside a paragraph, which keeps the gap below it.
    "img": "display: block; max-width: 100%; height: auto; border-radius: 12px;",
    "hr": (
        f"border: none; border-top: 1px solid {email_service.LINE}; "
        "margin: 20px 0;"
    ),
    "code": "font-family: Menlo, Consolas, monospace; font-size: 16px;",
}


def _walk(tokens: Sequence[Token]) -> Iterator[Token]:
    for token in tokens:
        yield token

        if token.children:
            yield from _walk(token.children)


def _image_key(token: Token) -> str | None:
    source = str(token.attrGet("src") or "")

    if not source.startswith(IMAGE_SCHEME):
        return None

    key = source[len(IMAGE_SCHEME) :]

    return key if _IMAGE_KEY.fullmatch(key) else None


# The keys of the images the message shows, in reading order.
def image_keys(message: str) -> list[str]:
    keys: list[str] = []

    for token in _walk(_MARKDOWN.parse(message)):
        if token.type != "image":
            continue

        key = _image_key(token)

        if key is not None and key not in keys:
            keys.append(key)

    return keys


# The opening words as plain text, for a list that has no room for formatting.
def preview(message: str) -> str:
    words: list[str] = []

    for block in _MARKDOWN.parse(message):
        if block.type != "inline" or not block.children:
            continue

        for token in block.children:
            if token.type in ("text", "code_inline"):
                words.append(token.content)
            elif token.type in ("softbreak", "hardbreak"):
                words.append(" ")

        words.append(" ")

    text = " ".join("".join(words).split())

    if len(text) <= _PREVIEW_LENGTH:
        return text

    return text[: _PREVIEW_LENGTH - 1].rstrip() + "…"


# cid_of turns an image key into the content id of its inline attachment.
def email_html(message: str, cid_of: Callable[[str], str]) -> str:
    tokens = _MARKDOWN.parse(message)

    for token in _walk(tokens):
        if token.nesting < 0:
            continue

        style = _STYLES.get(token.tag)

        if style is not None:
            token.attrSet("style", style)

        if token.type == "image":
            key = _image_key(token)

            if key is not None:
                token.attrSet("src", f"cid:{cid_of(key)}")

    return _MARKDOWN.renderer.render(tokens, _MARKDOWN.options, {})

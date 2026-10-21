import hashlib
import hmac
import re
from collections.abc import Collection, Iterable
from contextvars import ContextVar
from functools import lru_cache
from typing import Final

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESSIV

from app.core.config import settings

# The register's own format, never inside a longer run of token characters.
_TAX_CODE: Final[re.Pattern[str]] = re.compile(
    r"(?<![A-Za-z0-9+=_-])"
    r"[A-Z]{6}[0-9LMNPQRSTUV]{2}[ABCDEHLMPRST]"
    r"[0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]"
    r"(?![A-Za-z0-9+=_-])"
)

# SIV tag and ciphertext of the 16 characters, in hex.
_REF: Final[re.Pattern[str]] = re.compile(
    r"(?<![0-9A-Fa-f])[0-9A-Fa-f]{64}(?![0-9A-Fa-f])"
)

_KEY_LABEL: Final[bytes] = b"casa-michela/person-ref"

# On request.state: the tax codes a non-administrator reader may still be sent.
KEPT_TAX_CODES_STATE_KEY: Final[str] = "kept_tax_codes"

# The same for the request's own code; None for administrators.
_kept: ContextVar[frozenset[str] | None] = ContextVar("kept", default=None)

# Codes the request named by reference rather than bare.
_named: ContextVar[frozenset[str]] = ContextVar("named", default=frozenset())

# Deterministic: a person keeps one reference, which only the server can open.
_CIPHER: Final[AESSIV] = AESSIV(
    hmac.new(settings.jwt_access_secret.encode(), _KEY_LABEL, hashlib.sha256).digest()
)


@lru_cache(maxsize=4096)
def person_ref(tax_code: str) -> str:
    return _CIPHER.encrypt(tax_code.encode(), None).hex()


# None for anything this module did not write.
@lru_cache(maxsize=4096)
def tax_code_of(ref: str) -> str | None:
    try:
        return _CIPHER.decrypt(bytes.fromhex(ref), None).decode()

    except (InvalidTag, ValueError):
        return None


def hide_tax_codes(text: str, kept: Collection[str]) -> str:
    return _TAX_CODE.sub(
        lambda found: found[0] if found[0] in kept else person_ref(found[0]),
        text,
    )


def reveal_tax_codes(text: str, named: set[str] | None = None) -> str:
    def opened(found: re.Match[str]) -> str:
        code = tax_code_of(found[0].lower())

        if code is None:
            return found[0]

        if named is not None:
            named.add(code)

        return code

    return _REF.sub(opened, text)


def keep_for_reader(codes: frozenset[str] | None) -> None:
    _kept.set(codes)


def name_by_reference(codes: set[str]) -> None:
    _named.set(frozenset(codes))


# Someone else's code sent bare to a non-administrator was guessed, never read.
def guessed_tax_codes(codes: Iterable[str]) -> set[str]:
    kept = _kept.get()

    if kept is None:
        return set()

    named = _named.get()

    return {code for code in codes if code not in kept and code not in named}

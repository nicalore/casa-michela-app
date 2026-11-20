import re
import secrets
from typing import Final

from app.core.i18n import tr

_MIN_LENGTH: Final[int] = 12

_LENGTH_ERROR: Final[tuple[str, str]] = (
    f"La password deve contenere almeno {_MIN_LENGTH} caratteri",
    f"The password must contain at least {_MIN_LENGTH} characters",
)

_CHARACTER_RULES: Final[tuple[tuple[re.Pattern[str], tuple[str, str]], ...]] = (
    (
        re.compile(r"[a-z]"),
        (
            "La password deve contenere una lettera minuscola",
            "The password must contain a lowercase letter",
        ),
    ),
    (
        re.compile(r"[A-Z]"),
        (
            "La password deve contenere una lettera maiuscola",
            "The password must contain an uppercase letter",
        ),
    ),
    (
        re.compile(r"\d"),
        (
            "La password deve contenere un numero",
            "The password must contain a number",
        ),
    ),
    (
        re.compile(r"[^A-Za-z0-9]"),
        (
            "La password deve contenere un carattere speciale",
            "The password must contain a special character",
        ),
    ),
)


class PasswordPolicyError(ValueError):
    pass


def validate_password(password: str) -> None:
    if len(password) < _MIN_LENGTH:
        raise PasswordPolicyError(tr(*_LENGTH_ERROR))

    for pattern, message in _CHARACTER_RULES:
        if not pattern.search(password):
            raise PasswordPolicyError(tr(*message))

# Look-alikes left out (l, 1, I, O, 0): the password is read off an email and typed.
_LOWERCASE: Final[str] = "abcdefghijkmnpqrstuvwxyz"
_UPPERCASE: Final[str] = "ABCDEFGHJKLMNPQRSTUVWXYZ"
_DIGITS: Final[str] = "23456789"
_SPECIALS: Final[str] = "!#$%*+-=?@_"


def generate_temporary_password() -> str:
    classes = (_LOWERCASE, _UPPERCASE, _DIGITS, _SPECIALS)
    pool = "".join(classes)

    characters = [secrets.choice(group) for group in classes]
    characters += [secrets.choice(pool) for _ in range(_MIN_LENGTH - len(classes))]
    secrets.SystemRandom().shuffle(characters)

    password = "".join(characters)
    validate_password(password)

    return password

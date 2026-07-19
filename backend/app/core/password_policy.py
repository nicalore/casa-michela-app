import re
from typing import Final

_MIN_LENGTH: Final[int] = 12

_LENGTH_ERROR: Final[str] = f"La password deve contenere almeno {_MIN_LENGTH} caratteri"

_CHARACTER_RULES: Final[tuple[tuple[re.Pattern[str], str], ...]] = (
    (re.compile(r"[a-z]"), "La password deve contenere una lettera minuscola"),
    (re.compile(r"[A-Z]"), "La password deve contenere una lettera maiuscola"),
    (re.compile(r"\d"), "La password deve contenere un numero"),
    (re.compile(r"[^A-Za-z0-9]"), "La password deve contenere un carattere speciale"),
)


class PasswordPolicyError(ValueError):
    pass


def validate_password(password: str) -> None:
    if len(password) < _MIN_LENGTH:
        raise PasswordPolicyError(_LENGTH_ERROR)

    for pattern, message in _CHARACTER_RULES:
        if not pattern.search(password):
            raise PasswordPolicyError(message)
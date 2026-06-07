import re


class PasswordPolicyError(ValueError):
    pass


def validate_password(
    password: str,
) -> None:
    if len(password) < 12:
        raise PasswordPolicyError(
            "Password must be at least 12 characters long"
        )

    if not re.search(
        r"[a-z]",
        password,
    ):
        raise PasswordPolicyError(
            "Password must contain a lowercase letter"
        )

    if not re.search(
        r"[A-Z]",
        password,
    ):
        raise PasswordPolicyError(
            "Password must contain an uppercase letter"
        )

    if not re.search(
        r"\d",
        password,
    ):
        raise PasswordPolicyError(
            "Password must contain a digit"
        )

    if not re.search(
        r"[^A-Za-z0-9]",
        password,
    ):
        raise PasswordPolicyError(
            "Password must contain a special character"
        )
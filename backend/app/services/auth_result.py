from dataclasses import dataclass


@dataclass(slots=True)
class AuthResult:
    access_token: str
    refresh_token: str
    password_reset_required: bool
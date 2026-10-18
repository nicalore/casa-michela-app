from dataclasses import dataclass


@dataclass(slots=True)
class AuthResult:
    access_token: str
    refresh_token: str
    password_reset_required: bool
    # Whose session it is, and which: the sign-in is told to the account's devices.
    account_tax_code: str = ""
    session_id: str = ""
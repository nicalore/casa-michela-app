from pydantic import BaseModel


class ChangePasswordRequest(BaseModel):
    # Left out only by the change forced right after the sign-in.
    current_password: str | None = None
    new_password: str
    refresh_token: str

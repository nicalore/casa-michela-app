from pydantic import BaseModel


class PasswordResetRequest(BaseModel):
    username: str


class PasswordResetToken(BaseModel):
    token: str


class PasswordResetConfirm(PasswordResetToken):
    new_password: str
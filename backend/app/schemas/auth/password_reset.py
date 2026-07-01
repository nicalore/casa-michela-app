from pydantic import BaseModel


class PasswordResetRequest(BaseModel):
    username: str

class PasswordResetConfirm(BaseModel):
    token: str
    new_password: str
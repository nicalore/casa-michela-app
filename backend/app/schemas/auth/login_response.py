from pydantic import BaseModel


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    password_reset_required: bool
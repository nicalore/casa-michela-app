from pydantic import BaseModel

from app.models.account import ThemeModeEnum


class ThemeModeRequest(BaseModel):
    theme_mode: ThemeModeEnum

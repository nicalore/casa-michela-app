from pydantic import BaseModel

from app.models.account import ColourThemeEnum


class ColourThemeRequest(BaseModel):
    colour_theme: ColourThemeEnum

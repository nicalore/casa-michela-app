from pydantic import BaseModel

from app.models.account import LanguageEnum


class LanguageRequest(BaseModel):
    language: LanguageEnum

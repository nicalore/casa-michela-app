from datetime import datetime

from pydantic import BaseModel, Field

from app.models.app_update import AppUpdateRoleEnum


class AppUpdateImageResponse(BaseModel):
    key: str
    size: int


# A card of the IT managers' list.
class AppUpdateSummaryResponse(BaseModel):
    id: int
    title: str
    version: str
    preview: str
    author_name: str
    recipients: list[AppUpdateRoleEnum]
    created_at: datetime
    edited_at: datetime | None


class AppUpdateResponse(AppUpdateSummaryResponse):
    message: str
    images: list[AppUpdateImageResponse]
    # The optimistic concurrency token an edit echoes back.
    updated_at: datetime


# What a reader is shown: no author, no recipients.
class AppUpdateReadingResponse(BaseModel):
    id: int
    title: str
    version: str
    message: str
    images: list[AppUpdateImageResponse]


class AppUpdateRecipientsResponse(BaseModel):
    people: int


class AppUpdatesSeenWrite(BaseModel):
    ids: list[int] = Field(min_length=1, max_length=100)

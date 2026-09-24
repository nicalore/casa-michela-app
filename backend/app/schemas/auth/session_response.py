from datetime import datetime

from pydantic import BaseModel

from app.models.refresh_token import DeviceTypeEnum


class SessionResponse(BaseModel):
    session_id: str
    logged_in_at: datetime
    last_used_at: datetime
    device_type: DeviceTypeEnum
    device_name: str | None
    # The session the request itself came from.
    current: bool

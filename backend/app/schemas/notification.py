import re
from datetime import date, datetime
from typing import Annotated, Final, Literal, Self
from urllib.parse import urlsplit

from pydantic import BaseModel, ConfigDict, StringConstraints, model_validator

from app.core.time_band import TimeBandEnum
from app.models.notification import NotificationKindEnum
from app.models.push_device import PUSH_ADDRESS_LENGTH, PUSH_KEY_LENGTH

_WEB_KEYS_ERROR: Final[str] = "Le chiavi della sottoscrizione sono obbligatorie."
_PUSH_SERVICE_ERROR: Final[str] = "Servizio di notifiche non riconosciuto."
_APP_TOKEN_ERROR: Final[str] = "Token del dispositivo non valido."

# FCM and APNs tokens are plain: letters, digits, colons, dashes and underscores.
_APP_TOKEN: Final[re.Pattern[str]] = re.compile(r"[A-Za-z0-9_:-]+")

# The browsers' push services; the server posts to the endpoint, so no other host.
_PUSH_SERVICE_HOSTS: Final[tuple[str, ...]] = (
    "fcm.googleapis.com",
    "android.googleapis.com",
    "push.services.mozilla.com",
    "notify.windows.com",
    "push.apple.com",
)

PushAddress = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True,
        min_length=1,
        max_length=PUSH_ADDRESS_LENGTH,
    ),
]

PushKey = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True,
        min_length=1,
        max_length=PUSH_KEY_LENGTH,
    ),
]


class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    kind: NotificationKindEnum
    title: str
    body: str
    web_body: str | None
    calendar_date: date | None
    calendar_band: TimeBandEnum | None
    created_at: datetime
    read_at: datetime | None
    expires_at: datetime | None
    notice_id: int | None
    report_id: int | None
    pupil_tax_code: str | None
    teacher_tax_code: str | None
    teacher_note_id: int | None
    # Of a notice announced: the account's roles it reached, whose pages list it.
    notice_roles: list[str] = []


# A kind the account may turn on or off, and whether it is on.
class NotificationKindChoice(BaseModel):
    kind: NotificationKindEnum
    enabled: bool


class WebPushKeyResponse(BaseModel):
    # None while the server has no VAPID pair.
    public_key: str | None


def _is_push_service(address: str) -> bool:
    parts = urlsplit(address)
    host = (parts.hostname or "").lower()

    return parts.scheme == "https" and any(
        host == known or host.endswith(f".{known}") for known in _PUSH_SERVICE_HOSTS
    )


class PushDeviceWrite(BaseModel):
    platform: Literal["web", "android", "ios"]
    address: PushAddress
    p256dh: PushKey | None = None
    auth: PushKey | None = None

    @model_validator(mode="after")
    def _address_fits_platform(self) -> Self:
        if self.platform != "web":
            if not _APP_TOKEN.fullmatch(self.address):
                raise ValueError(_APP_TOKEN_ERROR)

            return self

        if self.p256dh is None or self.auth is None:
            raise ValueError(_WEB_KEYS_ERROR)

        if not _is_push_service(self.address):
            raise ValueError(_PUSH_SERVICE_ERROR)

        return self


class PushDeviceRemove(BaseModel):
    address: PushAddress

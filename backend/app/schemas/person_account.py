from datetime import datetime

from pydantic import BaseModel, Field

from app.models.account import AccessLapseEnum, AccountStatusEnum
from app.schemas.auth.session_response import SessionResponse


class PersonAccountResponse(BaseModel):
    username: str
    status: AccountStatusEnum
    # Set while no enrollment stands behind the account, whatever its status.
    lapse: AccessLapseEnum | None
    # A pupil whose parents answer for them; only then do autonomous bookings apply.
    answered_for: bool
    autonomous_bookings: bool
    last_login: datetime | None
    password_change_required: bool
    # Null unless the lock still holds.
    locked_until: datetime | None
    failed_login_attempts: int
    last_failed_login_attempt: datetime | None
    sessions: list[SessionResponse]


class AutonomousBookingsUpdate(BaseModel):
    enabled: bool


class AccountCreate(BaseModel):
    # Read only for a pupil the parents answer for.
    autonomous_bookings: bool = False
    # Those parents of the pupil who get an account along with theirs.
    parent_tax_codes: list[str] = Field(default_factory=list, max_length=2)


class OpenedAccountResponse(BaseModel):
    tax_code: str
    username: str

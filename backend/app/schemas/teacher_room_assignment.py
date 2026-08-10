from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.person import PersonOption
from app.schemas.room import RoomOption


class TeacherRoomAssignmentBase(BaseModel):
    date: date
    teacher_tax_code: str
    room_id: int


class TeacherRoomAssignmentCreate(TeacherRoomAssignmentBase):
    pass


class TeacherRoomAssignmentUpdate(BaseModel):
    room_id: int
    expected_updated_at: datetime | None = None


class TeacherRoomAssignmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    teacher_tax_code: str
    teacher: PersonOption
    room: RoomOption

    # Over capacity is worth saying and not worth refusing: the number is
    # optional to begin with, and nobody should be stopped by a count that was
    # never taken.
    warnings: list[str] = Field(default_factory=list)

    created_at: datetime
    updated_at: datetime

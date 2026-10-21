from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.time_step import assert_quarter_hour_step
from app.schemas.person import PersonOption
from app.schemas.room import RoomOption
from app.schemas.room_supervision import RoomSupervisionResponse
from app.schemas.validators import QuarterHourTimeRangeMixin


class TeacherRoomAssignmentBase(BaseModel):
    date: date
    teacher_tax_code: str
    room_id: int


# The whole day in one room.
class TeacherRoomAssignmentCreate(TeacherRoomAssignmentBase):
    pass


class TeacherRoomAssignmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    teacher_tax_code: str
    teacher: PersonOption
    room: RoomOption

    # In the room from here until the teacher's next row, or the end of the day.
    start_time: time

    # Over capacity warns rather than refuses: the count is optional anyway.
    warnings: list[str] = Field(default_factory=list)

    created_at: datetime
    updated_at: datetime


class RoomStretch(BaseModel):
    room_id: int
    start_time: time

    @field_validator("start_time")
    @classmethod
    def _time_step_of_15(cls, value: time) -> time:
        return assert_quarter_hour_step(value)


class RoomPlanTeacher(BaseModel):
    teacher_tax_code: str

    # Empty takes the teacher's rooms away; the first one runs from midnight.
    stretches: list[RoomStretch]


# No minimum length: a room may hold a single 15-minute lesson.
class RoomPlanShift(QuarterHourTimeRangeMixin):
    teacher_tax_code: str
    room_id: int


# Replaces the rooms and shifts of the listed teachers only.
class RoomPlanUpdate(BaseModel):
    teachers: list[RoomPlanTeacher]
    supervisions: list[RoomPlanShift]


class RoomPlanResponse(BaseModel):
    assignments: list[TeacherRoomAssignmentResponse]
    supervisions: list[RoomSupervisionResponse]
    warnings: list[str] = Field(default_factory=list)

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.validators import OptionalCleanStr, StrippedStr


class RoomBase(BaseModel):
    name: StrippedStr = Field(..., min_length=1, max_length=255)
    description: OptionalCleanStr = Field(None, max_length=1000)

    # Left out wherever nobody has counted. Null is not zero: an unmeasured room
    # takes as many as it takes, and the calendar warns rather than refuses.
    capacity: int | None = Field(None, gt=0)


class RoomCreate(RoomBase):
    pass


class RoomUpdate(RoomBase):
    pass


# The shape a room takes inside something else, next to AssociationSubjectOption
# and PersonOption. Capacity comes along because whoever is looking at a full
# room wants to know what full means.
class RoomOption(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    capacity: int | None = None


class RoomResponse(RoomBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime

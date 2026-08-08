from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.association_subject import SubjectAreaEnum
from app.schemas.validators import OptionalCleanStr, StrippedStr


# A discipline named by something else: a ministry subject containing it, a
# programme teaching it, a lesson asking for it. It carries the description too,
# because that is what says what the discipline is, and whoever picks one picks
# it from here.
class AssociationSubjectOption(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str | None = None


class AssociationSubjectBase(BaseModel):
    name: StrippedStr = Field(..., min_length=1)
    area: SubjectAreaEnum
    description: OptionalCleanStr = Field(None, max_length=1000)


class AssociationSubjectCreate(AssociationSubjectBase):
    pass


class AssociationSubjectUpdate(AssociationSubjectBase):
    pass


class AssociationSubjectResponse(AssociationSubjectBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.core import field_lengths
from app.models.study_program import EducationLevelEnum
from app.schemas.association_subject import AssociationSubjectOption
from app.schemas.validators import OptionalCleanStr, StrippedStr


class MinistrySubjectOption(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    association_subjects: list[AssociationSubjectOption] = Field(default_factory=list)


class StudyProgramBase(BaseModel):
    name: StrippedStr = Field(..., min_length=1, max_length=field_lengths.NAME)

    sector: OptionalCleanStr = Field(None, max_length=field_lengths.SECTOR)

    description: OptionalCleanStr = Field(
        None,
        max_length=field_lengths.DESCRIPTION,
    )
    level: EducationLevelEnum
    min_year: int = Field(..., ge=1)
    max_year: int = Field(..., ge=1)


class StudyProgramCreate(StudyProgramBase):
    ministry_subject_ids: list[int] = Field(default_factory=list)


class StudyProgramUpdate(StudyProgramBase):
    ministry_subject_ids: list[int] = Field(default_factory=list)


class StudyProgramResponse(StudyProgramBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    ministry_subjects: list[MinistrySubjectOption] = Field(default_factory=list)

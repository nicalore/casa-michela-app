from datetime import datetime
from typing import Final

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core import field_lengths
from app.models.association_subject import SubjectAreaEnum
from app.models.study_program import EducationLevelEnum
from app.schemas.association_subject import AssociationSubjectOption
from app.schemas.validators import OptionalCleanStr, StrippedStr

_DUPLICATE_AREAS_ERROR: Final[str] = (
    "Le aree selezionate non possono contenere duplicati."
)


class MinistrySubjectBase(BaseModel):
    name: StrippedStr = Field(..., min_length=1, max_length=field_lengths.NAME)
    level: EducationLevelEnum
    area: list[SubjectAreaEnum] = Field(..., min_length=1, max_length=3)
    description: OptionalCleanStr = Field(
        None,
        max_length=field_lengths.DESCRIPTION,
    )

    @field_validator("area")
    @classmethod
    def no_duplicate_areas(
        cls,
        value: list[SubjectAreaEnum],
    ) -> list[SubjectAreaEnum]:
        if len(set(value)) != len(value):
            raise ValueError(_DUPLICATE_AREAS_ERROR)

        return value


class MinistrySubjectCreate(MinistrySubjectBase):
    association_subject_ids: list[int] = Field(default_factory=list)


class MinistrySubjectUpdate(MinistrySubjectBase):
    association_subject_ids: list[int] = Field(default_factory=list)


class MinistrySubjectResponse(MinistrySubjectBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    association_subjects: list[AssociationSubjectOption] = Field(default_factory=list)

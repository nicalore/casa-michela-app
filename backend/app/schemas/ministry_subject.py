from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.association_subject import SubjectAreaEnum
from app.models.study_program import EducationLevelEnum
from app.schemas.association_subject import AssociationSubjectOption


class MinistrySubjectBase(BaseModel):
    name: str = Field(..., min_length=1)
    level: EducationLevelEnum
    area: list[SubjectAreaEnum] = Field(..., min_length=1, max_length=3)
    description: str | None = Field(None, max_length=1000)

    @field_validator("name")
    @classmethod
    def strip_whitespace(cls, v: str) -> str:
        return v.strip()

    @field_validator("description")
    @classmethod
    def clean_description(cls, v: str | None) -> str | None:
        if v is not None:
            cleaned = v.strip()
            return cleaned if len(cleaned) > 0 else None
        return v

    @field_validator("area")
    @classmethod
    def no_duplicate_areas(cls, v: list[SubjectAreaEnum]) -> list[SubjectAreaEnum]:
        if len(set(v)) != len(v):
            raise ValueError("Le aree selezionate non possono contenere duplicati.")
        return v


class MinistrySubjectCreate(MinistrySubjectBase):
    association_subject_ids: list[int] = Field(default_factory=list)


class MinistrySubjectUpdate(MinistrySubjectBase):
    association_subject_ids: list[int] = Field(default_factory=list)


class MinistrySubjectResponse(MinistrySubjectBase):
    id: int
    created_at: datetime
    association_subjects: list[AssociationSubjectOption] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.study_program import EducationLevelEnum
from app.schemas.association_subject import AssociationSubjectOption


#Aggiunte le discipline interne all'opzione della materia per mostrarle nel Tooltip del frontend
class MinistrySubjectOption(BaseModel):
    id: int
    name: str
    association_subjects: list[AssociationSubjectOption] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class StudyProgramBase(BaseModel):
    name: str = Field(..., min_length=1)
    description: str | None = Field(None, max_length=1000)
    level: EducationLevelEnum
    min_year: int = Field(..., ge=1)
    max_year: int = Field(..., ge=1)

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


class StudyProgramCreate(StudyProgramBase):
    ministry_subject_ids: list[int] = Field(default_factory=list)


class StudyProgramUpdate(StudyProgramBase):
    ministry_subject_ids: list[int] = Field(default_factory=list)


class StudyProgramResponse(StudyProgramBase):
    id: int
    created_at: datetime
    ministry_subjects: list[MinistrySubjectOption] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)
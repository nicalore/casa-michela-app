from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.association_subject import SubjectAreaEnum


class AssociationSubjectOption(BaseModel):
    id: int
    name: str

    model_config = ConfigDict(from_attributes=True)


class AssociationSubjectBase(BaseModel):
    name: str = Field(..., min_length=1)
    area: SubjectAreaEnum
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


class AssociationSubjectCreate(AssociationSubjectBase):
    pass


class AssociationSubjectUpdate(AssociationSubjectBase):
    pass


class AssociationSubjectResponse(AssociationSubjectBase):
    id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
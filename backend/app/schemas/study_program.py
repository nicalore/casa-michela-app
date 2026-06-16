from pydantic import BaseModel, Field, field_validator


class StudyProgramBase(BaseModel):
    name: str = Field(..., min_length=1)
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

class StudyProgramCreate(StudyProgramBase):
    pass

class StudyProgramUpdate(StudyProgramBase):
    pass

class StudyProgramResponse(StudyProgramBase):
    id: int
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class SchoolStudyProgramOption(BaseModel):
    id: int
    name: str
    level: str

    model_config = ConfigDict(from_attributes=True)


class SchoolBase(BaseModel):
    name: str = Field(..., min_length=1, description="Nome della scuola")
    city: str = Field(..., min_length=1, description="Città della scuola")
    province: str = Field(..., min_length=2, max_length=2, description="Provincia (es. VI)")


class SchoolCreate(SchoolBase):
    is_private: bool = False
    mechanographic_code: str = ""
    study_program_ids: list[int] = Field(default_factory=list)


class SchoolUpdate(SchoolBase):
    is_private: bool = False
    mechanographic_code: str = ""
    study_program_ids: list[int] = Field(default_factory=list)


class SchoolResponse(SchoolBase):
    mechanographic_code: str
    created_at: datetime
    study_programs: list[SchoolStudyProgramOption] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)
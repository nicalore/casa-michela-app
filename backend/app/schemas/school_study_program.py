from pydantic import BaseModel, ConfigDict


class SchoolOption(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    mechanographic_code: str | None = None


class StudyProgramOption(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    level: str
    min_year: int
    max_year: int


class SchoolStudyProgramBase(BaseModel):
    school_id: int
    study_program_id: int


class SchoolStudyProgramCreate(SchoolStudyProgramBase):
    pass


class SchoolStudyProgramResponse(SchoolStudyProgramBase):
    model_config = ConfigDict(from_attributes=True)

    school: SchoolOption
    study_program: StudyProgramOption
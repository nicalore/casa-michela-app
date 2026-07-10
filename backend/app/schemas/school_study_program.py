from pydantic import BaseModel, ConfigDict


class SchoolOption(BaseModel):
    id: int
    name: str
    mechanographic_code: str | None = None  # mantenuto per la visualizzazione

    model_config = ConfigDict(from_attributes=True)


class StudyProgramOption(BaseModel):
    id: int
    name: str
    level: str
    min_year: int
    max_year: int

    model_config = ConfigDict(from_attributes=True)


class SchoolStudyProgramBase(BaseModel):
    school_id: int
    study_program_id: int


class SchoolStudyProgramCreate(SchoolStudyProgramBase):
    pass


class SchoolStudyProgramResponse(SchoolStudyProgramBase):
    school: SchoolOption
    study_program: StudyProgramOption

    model_config = ConfigDict(from_attributes=True)
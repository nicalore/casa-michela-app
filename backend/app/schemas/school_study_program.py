from pydantic import BaseModel, ConfigDict


class SchoolOption(BaseModel):
    mechanographic_code: str
    name: str

    model_config = ConfigDict(from_attributes=True)


class StudyProgramOption(BaseModel):
    id: int
    name: str
    level: str
    min_year: int
    max_year: int

    model_config = ConfigDict(from_attributes=True)


class SchoolStudyProgramBase(BaseModel):
    school_mechanographic_code: str
    study_program_id: int


class SchoolStudyProgramCreate(SchoolStudyProgramBase):
    pass


class SchoolStudyProgramResponse(SchoolStudyProgramBase):
    school: SchoolOption
    study_program: StudyProgramOption

    model_config = ConfigDict(from_attributes=True)
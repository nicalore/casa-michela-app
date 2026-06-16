from pydantic import BaseModel


class SubjectOption(BaseModel):
    id: int
    discipline: str
    specialization: str | None = None

class SchoolOption(BaseModel):
    mechanographic_code: str
    name: str

class StudyProgramOption(BaseModel):
    id: int
    name: str

class OfferingOptions(BaseModel):
    schools: list[SchoolOption]
    study_programs: list[StudyProgramOption]
    subjects: list[SubjectOption]

class TeachingOfferingBase(BaseModel):
    school_mechanographic_code: str
    study_program_id: int
    level: str
    years: list[int]
    subject_ids: list[int]

class TeachingOfferingCreate(TeachingOfferingBase):
    pass

class TeachingOfferingUpdate(TeachingOfferingBase):
    pass

class TeachingOfferingResponse(TeachingOfferingBase):
    id: int
    school_name: str
    study_program_name: str
    subjects: list[SubjectOption]
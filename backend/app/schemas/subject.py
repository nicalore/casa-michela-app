from pydantic import BaseModel


class SubjectGrouped(BaseModel):
    discipline: str
    areas: list[str]

class SubjectCreate(BaseModel):
    discipline: str
    areas: list[str]

class SubjectUpdate(BaseModel):
    discipline: str
    areas: list[str]
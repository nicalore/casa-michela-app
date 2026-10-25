from pydantic import BaseModel


class CriterionUpdate(BaseModel):
    met: bool


class TeacherEvaluationResponse(BaseModel):
    met_criteria: list[str]
    rating: float

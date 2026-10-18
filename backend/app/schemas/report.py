from datetime import datetime

from pydantic import BaseModel

from app.models.report import ReportKindEnum


class ReportCorrection(BaseModel):
    field: str
    value: str


# One report as its readers see it; read is the caller's own.
class ReportResponse(BaseModel):
    id: int
    kind: ReportKindEnum
    created_at: datetime
    read: bool
    reporter_tax_code: str
    reporter_name: str
    reporter_email: str
    # The hat worn when sending, as the user reads it; None if unknown.
    reporter_role: str | None
    # Whose data is wrong, for personal data.
    person_tax_code: str | None
    person_name: str | None
    title: str | None
    description: str | None
    corrections: list[ReportCorrection] | None

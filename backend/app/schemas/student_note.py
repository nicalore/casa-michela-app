from datetime import date, datetime

from pydantic import BaseModel, Field

from app.core import field_lengths
from app.schemas.validators import CleanStr


# Methodological and technical notes alike.
class StudentNoteResponse(BaseModel):
    id: int
    text: str
    author_tax_code: str
    author_name: str
    created_at: datetime
    updated_at: datetime


class StudentNoteWrite(BaseModel):
    text: CleanStr = Field(
        ...,
        min_length=1,
        max_length=field_lengths.STUDENT_NOTE,
    )


class TeacherNoteResponse(BaseModel):
    id: int
    text: str
    author_tax_code: str
    author_name: str
    created_at: datetime
    lesson_date: date
    subject: str


class TeacherNoteCreate(StudentNoteWrite):
    # One of the lesson's bookings: the subject the note is about.
    booking_id: int

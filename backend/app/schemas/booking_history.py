from datetime import date, datetime, time
from typing import Literal

from pydantic import BaseModel

BookingKind = Literal["SUBJECT", "DISCIPLINE", "SERVICE"]


class BookingHistoryPersonResponse(BaseModel):
    tax_code: str
    first_name: str
    last_name: str


class BookingHistoryLessonResponse(BaseModel):
    id: int
    teacher: BookingHistoryPersonResponse
    start_time: time
    end_time: time


class BookingHistoryBookingResponse(BaseModel):
    id: int
    kind: BookingKind

    # The disciplines, or the service; the subject only where it says more.
    name: str
    subject: str | None
    duration: int
    tags: list[str]
    topic: str | None

    # Lessons are shown only once their band is published.
    published: bool
    lessons: list[BookingHistoryLessonResponse]


class BookingHistoryStretchResponse(BaseModel):
    id: int
    mode: Literal["presence", "online"]
    band: str
    start_time: time
    end_time: time
    booker: BookingHistoryPersonResponse
    booked_at: datetime
    bookings: list[BookingHistoryBookingResponse]


class BookingHistoryDayResponse(BaseModel):
    date: date
    stretches: list[BookingHistoryStretchResponse]


class BookingHistoryMonthResponse(BaseModel):
    booked_days: int
    booked_minutes: int
    presence_minutes: int
    online_minutes: int
    days: list[BookingHistoryDayResponse]

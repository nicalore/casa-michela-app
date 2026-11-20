from datetime import date, datetime, time
from typing import Final, Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core import field_lengths
from app.core.i18n import tr
from app.models.booking import BookingTagEnum
from app.models.booking_preferred_teacher import MAX_PREFERRED_TEACHERS_PER_BOOKING
from app.schemas.association_subject import AssociationSubjectOption
from app.schemas.person import PersonOption
from app.schemas.validators import OptionalCleanStr

_DURATION_STEP_ERROR: Final[tuple[str, str]] = (
    "La durata deve essere espressa in multipli di 15 minuti.",
    "The duration must be in steps of 15 minutes.",
)

_ONE_REQUEST_KIND_ERROR: Final[tuple[str, str]] = (
    "Indica una materia ministeriale, oppure una disciplina, oppure un servizio: uno "
    "solo dei tre.",
    "Give a curriculum subject, a discipline or a service: only one of the three.",
)

_NO_SUBJECTS_ERROR: Final[tuple[str, str]] = (
    "Seleziona una disciplina per questa materia ministeriale.",
    "Select a discipline for this curriculum subject.",
)

_SEVERAL_SUBJECTS_ERROR: Final[tuple[str, str]] = (
    "Una prenotazione riguarda una sola disciplina: per più discipline servono "
    "prenotazioni separate.",
    "A booking covers a single discipline: several disciplines need separate bookings.",
)

_SUBJECTS_ON_WRONG_KIND_ERROR: Final[tuple[str, str]] = (
    "Le discipline si elencano solo sotto una materia ministeriale.",
    "Disciplines are listed only under a curriculum subject.",
)

_SERVICE_HAS_NO_TAG_OR_TOPIC_ERROR: Final[tuple[str, str]] = (
    "Un servizio non ha argomento né tipo di lezione.",
    "A service has no topic or lesson type.",
)

_NO_TAGS_ERROR: Final[tuple[str, str]] = (
    "Indica almeno un tipo di lezione.",
    "Give at least one lesson type.",
)


class BookingBase(BaseModel):
    duration: int = Field(..., ge=15, le=300)

    ministry_subject_id: int | None = None
    association_subject_ids: list[int] = Field(default_factory=list)
    association_subject_id: int | None = None
    service_name: str | None = None

    tags: list[BookingTagEnum] = Field(default_factory=list)

    topic: OptionalCleanStr = Field(None, max_length=field_lengths.TOPIC)
    notes: OptionalCleanStr = Field(None, max_length=field_lengths.NOTES)

    preferred_teacher_tax_codes: list[str] = Field(
        default_factory=list,
        max_length=MAX_PREFERRED_TEACHERS_PER_BOOKING,
    )

    @field_validator("duration")
    @classmethod
    def _duration_step_of_15(cls, value: int) -> int:
        if value % 15 != 0:
            raise ValueError(tr(*_DURATION_STEP_ERROR))

        return value

    @field_validator("preferred_teacher_tax_codes", mode="before")
    @classmethod
    def _drop_duplicate_tax_codes(cls, value: object) -> object:
        if isinstance(value, list):
            return list(dict.fromkeys(value))

        return value

    @model_validator(mode="after")
    def _exactly_one_request_kind(self) -> Self:
        kinds = [
            self.ministry_subject_id is not None,
            self.association_subject_id is not None,
            self.service_name is not None,
        ]

        if sum(kinds) != 1:
            raise ValueError(tr(*_ONE_REQUEST_KIND_ERROR))

        if self.ministry_subject_id is not None and not self.association_subject_ids:
            raise ValueError(tr(*_NO_SUBJECTS_ERROR))

        if len(set(self.association_subject_ids)) > 1:
            raise ValueError(tr(*_SEVERAL_SUBJECTS_ERROR))

        if self.ministry_subject_id is None and self.association_subject_ids:
            raise ValueError(tr(*_SUBJECTS_ON_WRONG_KIND_ERROR))

        if self.service_name is not None and (self.tags or self.topic):
            raise ValueError(tr(*_SERVICE_HAS_NO_TAG_OR_TOPIC_ERROR))

        if self.service_name is None and not self.tags:
            raise ValueError(tr(*_NO_TAGS_ERROR))

        return self


class BookingCreate(BookingBase):
    presence_id: int


class BookingUpdate(BookingBase):
    presence_id: int | None = None
    expected_updated_at: datetime | None = None


class PresenceSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    date: date
    start_time: time
    end_time: time
    student: PersonOption


class BookingSummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    duration: int

    ministry_subject_id: int | None = None
    association_subjects: list[AssociationSubjectOption] = Field(default_factory=list)
    association_subject: AssociationSubjectOption | None = None
    service_name: str | None = None
    tags: list[BookingTagEnum] = Field(default_factory=list)
    topic: str | None = None
    notes: str | None = None
    preferred_teachers: list[PersonOption] = Field(default_factory=list)
    not_preferred_teachers: list[PersonOption] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime


class BookingResponse(BookingSummaryResponse):
    presence_id: int
    presence: PresenceSummary

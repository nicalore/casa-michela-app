from datetime import datetime
from typing import Final, Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core import field_lengths
from app.models.study_program import (
    YEARS_BY_TRACK,
    EducationLevelEnum,
    HighSchoolTrackEnum,
)
from app.schemas.association_subject import AssociationSubjectOption
from app.schemas.validators import OptionalCleanStr, StrippedStr

_TRACK_REQUIRED_ERROR: Final[str] = (
    "Per la scuola secondaria di II grado indica l'articolazione: biennio, "
    "triennio o percorso quadriennale."
)

_TRACK_ONLY_FOR_HIGH_SCHOOL_ERROR: Final[str] = (
    "L'articolazione si indica solo per la scuola secondaria di II grado."
)

_YEARS_REQUIRED_ERROR: Final[str] = (
    "Indica l'anno iniziale e l'anno finale del percorso."
)

_YEARS_OUT_OF_ORDER_ERROR: Final[str] = (
    "L'anno iniziale non può essere successivo all'anno finale."
)


class MinistrySubjectOption(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    association_subjects: list[AssociationSubjectOption] = Field(default_factory=list)


class StudyProgramBase(BaseModel):
    name: StrippedStr = Field(..., min_length=1, max_length=field_lengths.NAME)

    sector: OptionalCleanStr = Field(None, max_length=field_lengths.SECTOR)

    description: OptionalCleanStr = Field(
        None,
        max_length=field_lengths.DESCRIPTION,
    )
    level: EducationLevelEnum

    # Null where none exists: only high school is split into cycles.
    high_school_track: HighSchoolTrackEnum | None = None


# The years are optional on the way in only. The response declares them
# required again, so reading a programme never hands back a null span.
class StudyProgramWrite(StudyProgramBase):
    min_year: int | None = Field(None, ge=1)
    max_year: int | None = Field(None, ge=1)

    ministry_subject_ids: list[int] = Field(default_factory=list)

    @model_validator(mode="after")
    def _years_follow_the_track(self) -> Self:
        if self.level is EducationLevelEnum.HIGH_SCHOOL:
            if self.high_school_track is None:
                raise ValueError(_TRACK_REQUIRED_ERROR)

            # The track wins: whatever the client sent is overwritten.
            self.min_year, self.max_year = YEARS_BY_TRACK[self.high_school_track]

            return self

        if self.high_school_track is not None:
            raise ValueError(_TRACK_ONLY_FOR_HIGH_SCHOOL_ERROR)

        if self.min_year is None or self.max_year is None:
            raise ValueError(_YEARS_REQUIRED_ERROR)

        if self.min_year > self.max_year:
            raise ValueError(_YEARS_OUT_OF_ORDER_ERROR)

        return self

    # Never null once validated; spares every caller an `or 0`.
    @property
    def years(self) -> tuple[int, int]:
        return self.min_year or 1, self.max_year or 1


class StudyProgramCreate(StudyProgramWrite):
    pass


class StudyProgramUpdate(StudyProgramWrite):
    pass


class StudyProgramResponse(StudyProgramBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    min_year: int
    max_year: int
    ministry_subjects: list[MinistrySubjectOption] = Field(default_factory=list)

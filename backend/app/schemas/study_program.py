from datetime import datetime
from typing import Final, Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core import field_lengths
from app.core.labels import HIGH_SCHOOL_TRACK_LABELS
from app.models.study_program import (
    YEARS_BY_TRACK,
    EducationLevelEnum,
    HighSchoolTrackEnum,
)
from app.schemas.association_subject import AssociationSubjectOption
from app.schemas.validators import OptionalCleanStr, StrippedStr

_TRACK_REQUIRED_ERROR: Final[str] = (
    "Per la scuola secondaria di II grado indica l'articolazione: biennio, "
    "triennio o altro."
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

_YEARS_OF_A_FIXED_TRACK_ERROR: Final[str] = "Per gli anni {years} scegli {track}."


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

            fixed_years = YEARS_BY_TRACK.get(self.high_school_track)

            # A fixed track wins: whatever the client sent is overwritten.
            if fixed_years is not None:
                self.min_year, self.max_year = fixed_years

                return self

        elif self.high_school_track is not None:
            raise ValueError(_TRACK_ONLY_FOR_HIGH_SCHOOL_ERROR)

        if self.min_year is None or self.max_year is None:
            raise ValueError(_YEARS_REQUIRED_ERROR)

        if self.min_year > self.max_year:
            raise ValueError(_YEARS_OUT_OF_ORDER_ERROR)

        if self.high_school_track is HighSchoolTrackEnum.OTHER:
            for track, years in YEARS_BY_TRACK.items():
                if years == (self.min_year, self.max_year):
                    raise ValueError(
                        _YEARS_OF_A_FIXED_TRACK_ERROR.format(
                            years=f"{years[0]}-{years[1]}",
                            track=HIGH_SCHOOL_TRACK_LABELS[track],
                        )
                    )

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

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class SchoolStudyProgramOption(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int

    # The full name, sector included: here the programme is named inside a
    # school's list, where the bare name does not say which branch it belongs to.
    name: str = Field(validation_alias="display_name")

    level: str


class SchoolBase(BaseModel):
    name: str = Field(..., min_length=1, description="Nome della scuola")
    city: str = Field(..., min_length=1, description="Città della scuola")
    province: str = Field(
        ...,
        min_length=2,
        max_length=2,
        description="Provincia (es. VI)",
    )
    mechanographic_code: str | None = Field(
        default=None,
        max_length=100,
        description=(
            "Codice meccanografico (opzionale, anche multiplo per istituti "
            "con più sedi/livelli)"
        ),
    )

    @field_validator("mechanographic_code")
    @classmethod
    def _normalize_code(cls, value: str | None) -> str | None:
        # An empty string must become NULL, so that "no code" has a single
        # representation instead of a mix of '' and NULL in the table.
        if value is None:
            return None

        normalized = value.strip().upper()

        return normalized or None


class SchoolCreate(SchoolBase):
    study_program_ids: list[int] = Field(default_factory=list)


class SchoolUpdate(SchoolBase):
    study_program_ids: list[int] = Field(default_factory=list)


class SchoolResponse(SchoolBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    study_programs: list[SchoolStudyProgramOption] = Field(default_factory=list)
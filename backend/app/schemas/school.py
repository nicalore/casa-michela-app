from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core import field_lengths


class SchoolStudyProgramOption(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int

    name: str = Field(validation_alias="display_name")

    level: str


class SchoolBase(BaseModel):
    name: str = Field(
        ...,
        min_length=1,
        max_length=field_lengths.NAME,
        description="Nome della scuola",
    )
    city: str = Field(
        ...,
        min_length=1,
        max_length=field_lengths.CITY,
        description="Città della scuola",
    )
    province: str = Field(
        ...,
        min_length=field_lengths.PROVINCE,
        max_length=field_lengths.PROVINCE,
        description="Provincia (es. VI)",
    )
    mechanographic_code: str | None = Field(
        default=None,
        max_length=field_lengths.MECHANOGRAPHIC_CODE,
        description=(
            "Codice meccanografico (opzionale, anche multiplo per istituti "
            "con più sedi/livelli)"
        ),
    )

    @field_validator("mechanographic_code")
    @classmethod
    def _normalize_code(cls, value: str | None) -> str | None:
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

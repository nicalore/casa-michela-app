from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class SchoolStudyProgramOption(BaseModel):
    id: int
    name: str
    level: str

    model_config = ConfigDict(from_attributes=True)


class SchoolBase(BaseModel):
    name: str = Field(..., min_length=1, description="Nome della scuola")
    city: str = Field(..., min_length=1, description="Città della scuola")
    province: str = Field(..., min_length=2, max_length=2, description="Provincia (es. VI)")
    mechanographic_code: str | None = Field(
        default=None,
        max_length=20,
        description="Codice meccanografico (opzionale)",
    )

    @field_validator("mechanographic_code")
    @classmethod
    def _normalize_code(cls, value: str | None) -> str | None:
        # Normalizza a maiuscolo e converte stringa vuota in NULL,
        # così "nessun codice" è sempre None e non ci sono '' sparsi in tabella.
        if value is None:
            return None
        value = value.strip().upper()
        return value or None


class SchoolCreate(SchoolBase):
    study_program_ids: list[int] = Field(default_factory=list)


class SchoolUpdate(SchoolBase):
    study_program_ids: list[int] = Field(default_factory=list)


class SchoolResponse(SchoolBase):
    id: int
    created_at: datetime
    study_programs: list[SchoolStudyProgramOption] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)
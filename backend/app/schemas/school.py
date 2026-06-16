from pydantic import BaseModel, Field, field_validator


class SchoolBase(BaseModel):
    name: str = Field(..., min_length=1)
    city: str = Field(..., min_length=1)
    province: str = Field(..., min_length=2, max_length=2)

    @field_validator("province")
    @classmethod
    def to_uppercase(cls, v: str) -> str:
        return v.upper().strip()

    @field_validator("name", "city")
    @classmethod
    def strip_whitespace(cls, v: str) -> str:
        return v.strip()

class SchoolCreate(SchoolBase):
    mechanographic_code: str = "" # Opzionale, lo calcoliamo noi se privata
    is_private: bool = False

class SchoolUpdate(SchoolBase):
    mechanographic_code: str = ""
    is_private: bool = False

class SchoolResponse(SchoolBase):
    mechanographic_code: str

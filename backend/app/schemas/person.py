from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict


class PersonResponse(BaseModel):
    fiscal_code: str
    first_name: str
    last_name: str
    roles: List[str]
    created_at: datetime
    profile_image_url: Optional[str] = None
    
    # Campi per i filtri
    city: Optional['str | None']
    birth_date: Optional[date] = None
    children_count: Optional[int] = None
    is_active_collaborator: Optional[bool] = None
    enrollment_year: Optional[str] = None
    education_level: Optional[str] = None
    school_name: Optional[str] = None
    school_class: Optional[str] = None
    study_program: Optional[str] = None
    early_exit: Optional[bool] = None
    collaboration_type: Optional[str] = None
    taught_subjects: List[str] = []
    course_type: Optional[str] = None
    is_medical_certificate_valid: Optional[bool] = None

    model_config = ConfigDict(from_attributes=True)
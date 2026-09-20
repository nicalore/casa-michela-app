from pydantic import BaseModel, Field

from app.core import field_lengths
from app.schemas.validators import CleanStr


# A report of something wrong with the app, forwarded to whoever builds it.
class ProblemReport(BaseModel):
    description: CleanStr = Field(
        ...,
        min_length=1,
        max_length=field_lengths.DESCRIPTION,
    )

from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints

from app.models.seen_tour import TOUR_SLUG_LENGTH

TourSlug = Annotated[
    str,
    StringConstraints(
        min_length=1,
        max_length=TOUR_SLUG_LENGTH,
        pattern=r"^[A-Za-z0-9_.-]+$",
    ),
]


class SeenToursWrite(BaseModel):
    # Slug to the version seen; a lower version than the stored one is ignored.
    seen: dict[TourSlug, Annotated[int, Field(gt=0)]] = Field(..., max_length=200)

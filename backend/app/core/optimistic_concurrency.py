from datetime import datetime
from typing import Final

from fastapi import HTTPException, status

from app.models.mixins import UpdatedAtMixin

# The subject is the author, so the sentence reads well with any label.
_STALE_ENTITY_ERROR: Final[str] = (
    "Qualcuno ha modificato {entity_label} nel frattempo. "
    "Ricarica la pagina e riprova."
)


def stale_conflict(entity_label: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=_STALE_ENTITY_ERROR.format(entity_label=entity_label),
    )


def assert_not_stale(
    entity: UpdatedAtMixin,
    expected_updated_at: datetime | None,
    *,
    entity_label: str,
) -> None:
    # Callers that send no expected_updated_at are not blocked, so requests
    # predating optimistic concurrency keep working.
    if expected_updated_at is None:
        return

    if _to_millisecond(entity.updated_at) != _to_millisecond(expected_updated_at):
        raise stale_conflict(entity_label)


# Web clients keep milliseconds, so sub-second writes still read as two versions.
def _to_millisecond(moment: datetime) -> datetime:
    return moment.replace(microsecond=moment.microsecond // 1000 * 1000)

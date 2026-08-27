from datetime import datetime
from typing import Final

from fastapi import HTTPException, status

from app.models.mixins import UpdatedAtMixin

# The subject is the author, so the sentence reads well with any label.
_STALE_ENTITY_ERROR: Final[str] = (
    "Un altro utente ha modificato {entity_label} nel frattempo. "
    "Ricarica la pagina e riprova."
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

    stored = entity.updated_at.replace(microsecond=0)

    if stored != expected_updated_at.replace(microsecond=0):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_STALE_ENTITY_ERROR.format(entity_label=entity_label),
        )

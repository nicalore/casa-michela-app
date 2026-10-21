from enum import StrEnum
from pathlib import Path
from typing import Final

from fastapi import APIRouter, HTTPException, Response, status

from app.api.rbac import CurrentIdentity
from app.core.downloads import inline_disposition
from app.core.storage import (
    COOKIE_DOCUMENT,
    PRIVACY_DOCUMENT,
    REGULATION_DOCUMENT,
    STATUTE_DOCUMENT,
    TERMS_DOCUMENT,
)

# The association's own papers, read by whoever is signed in.
router = APIRouter(prefix="/documents", tags=["documents"])

_MISSING_DOCUMENT_ERROR: Final[str] = "Documento non ancora disponibile."


class DocumentName(StrEnum):
    REGULATION = "regulation"
    STATUTE = "statute"
    TERMS = "terms"
    PRIVACY = "privacy"
    COOKIES = "cookies"


_FILES: Final[dict[DocumentName, Path]] = {
    DocumentName.REGULATION: REGULATION_DOCUMENT,
    DocumentName.STATUTE: STATUTE_DOCUMENT,
    DocumentName.TERMS: TERMS_DOCUMENT,
    DocumentName.PRIVACY: PRIVACY_DOCUMENT,
    DocumentName.COOKIES: COOKIE_DOCUMENT,
}


@router.get("/{name}", status_code=status.HTTP_200_OK, response_class=Response)
async def document(name: DocumentName, identity: CurrentIdentity) -> Response:
    path = _FILES[name]

    if not path.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_MISSING_DOCUMENT_ERROR,
        )

    return Response(
        content=path.read_bytes(),
        media_type="application/pdf",
        headers={"Content-Disposition": inline_disposition(path.name)},
    )

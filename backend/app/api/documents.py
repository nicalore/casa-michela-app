from enum import StrEnum
from pathlib import Path
from typing import Final

from fastapi import APIRouter, HTTPException, Response, status

from app.api.rbac import CurrentIdentity
from app.core.downloads import inline_disposition
from app.core.i18n import ENGLISH, request_language, tr
from app.core.storage import (
    COOKIE_DOCUMENT,
    ENGLISH_COOKIE_DOCUMENT,
    ENGLISH_PRIVACY_DOCUMENT,
    ENGLISH_TERMS_DOCUMENT,
    PRIVACY_DOCUMENT,
    REGULATION_DOCUMENT,
    STATUTE_DOCUMENT,
    TERMS_DOCUMENT,
)

# The association's own papers, read by whoever is signed in.
router = APIRouter(prefix="/documents", tags=["documents"])

_MISSING_DOCUMENT_ERROR: Final[tuple[str, str]] = (
    "Documento non ancora disponibile.",
    "Document not available yet.",
)


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

# Statute and regulation are official papers and stay Italian.
_ENGLISH_FILES: Final[dict[DocumentName, Path]] = {
    DocumentName.TERMS: ENGLISH_TERMS_DOCUMENT,
    DocumentName.PRIVACY: ENGLISH_PRIVACY_DOCUMENT,
    DocumentName.COOKIES: ENGLISH_COOKIE_DOCUMENT,
}


# The Italian print stands in until the English one is on the server.
def _file_of(name: DocumentName) -> Path:
    english = _ENGLISH_FILES.get(name)

    if request_language() == ENGLISH and english and english.is_file():
        return english

    return _FILES[name]


@router.get("/{name}", status_code=status.HTTP_200_OK, response_class=Response)
async def document(name: DocumentName, identity: CurrentIdentity) -> Response:
    path = _file_of(name)

    if not path.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=tr(*_MISSING_DOCUMENT_ERROR),
        )

    return Response(
        content=path.read_bytes(),
        media_type="application/pdf",
        headers={"Content-Disposition": inline_disposition(path.name)},
    )

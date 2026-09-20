from fastapi import APIRouter, Response, status

from app.api.rbac import CurrentIdentity
from app.core.downloads import inline_disposition
from app.core.storage import REGULATION_DOCUMENT

# The association's own papers, read by whoever is signed in.
router = APIRouter(prefix="/documents", tags=["documents"])


@router.get("/regulation", status_code=status.HTTP_200_OK, response_class=Response)
async def regulation(identity: CurrentIdentity) -> Response:
    return Response(
        content=REGULATION_DOCUMENT.read_bytes(),
        media_type="application/pdf",
        headers={"Content-Disposition": inline_disposition(REGULATION_DOCUMENT.name)},
    )

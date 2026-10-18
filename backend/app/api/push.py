from typing import Final

from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert

from app.api.current_account import CurrentAccount, CurrentSessionId
from app.api.dependencies import DbSession
from app.core.config import settings
from app.models.push_device import PushDevice, PushPlatformEnum
from app.schemas.notification import (
    PushDeviceRemove,
    PushDeviceWrite,
    WebPushKeyResponse,
)
from app.services.push import web_push_enabled

# Where each account's notifications are pushed, one row per browser or app install.
router = APIRouter(prefix="/push", tags=["push"])

# A family's browsers and phones; past that the oldest goes, so no account fans out.
_DEVICE_LIMIT: Final[int] = 10

_UNKNOWN_SESSION_ERROR: Final[str] = (
    "Sessione in uso non riconosciuta: esci e accedi di nuovo"
)


@router.get("/web-key")
async def web_key(current_account: CurrentAccount) -> WebPushKeyResponse:
    return WebPushKeyResponse(
        public_key=settings.vapid_public_key if web_push_enabled() else None,
    )


# A browser or app signed in by someone else before now changes hands.
@router.put("/devices", status_code=status.HTTP_204_NO_CONTENT)
async def register_device(
    payload: PushDeviceWrite,
    current_account: CurrentAccount,
    current_session_id: CurrentSessionId,
    db: DbSession,
) -> Response:
    # Pushes follow the session: one never named could never be told it ended.
    if current_session_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_UNKNOWN_SESSION_ERROR,
        )

    statement = insert(PushDevice).values(
        account_tax_code=current_account.tax_code,
        session_id=current_session_id,
        platform=PushPlatformEnum(payload.platform.upper()),
        address=payload.address,
        p256dh=payload.p256dh,
        auth=payload.auth,
    )

    await db.execute(
        statement.on_conflict_do_update(
            index_elements=["address"],
            set_={
                "account_tax_code": statement.excluded.account_tax_code,
                "session_id": statement.excluded.session_id,
                "platform": statement.excluded.platform,
                "p256dh": statement.excluded.p256dh,
                "auth": statement.excluded.auth,
                "updated_at": func.now(),
            },
        )
    )

    kept = (
        select(PushDevice.id)
        .where(PushDevice.account_tax_code == current_account.tax_code)
        .order_by(PushDevice.updated_at.desc(), PushDevice.id.desc())
        .limit(_DEVICE_LIMIT)
    )
    await db.execute(
        delete(PushDevice).where(
            PushDevice.account_tax_code == current_account.tax_code,
            PushDevice.id.not_in(kept),
        )
    )
    await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/devices", status_code=status.HTTP_204_NO_CONTENT)
async def forget_device(
    payload: PushDeviceRemove,
    current_account: CurrentAccount,
    db: DbSession,
) -> Response:
    await db.execute(
        delete(PushDevice).where(
            PushDevice.address == payload.address,
            PushDevice.account_tax_code == current_account.tax_code,
        )
    )
    await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)

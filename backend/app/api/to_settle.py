from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.dependencies import DbSession
from app.api.rbac import IdentityContext, require_role
from app.core.booking_window import now_in_rome
from app.schemas.to_settle import DebtorResponse, OwedItemResponse, ToSettleResponse
from app.services.to_settle import debtors

router = APIRouter(prefix="/accounting/to-settle", tags=["accounting"])

Admin = Annotated[IdentityContext, Depends(require_role("ADMIN"))]


# Whoever owes something today, whether they came lately or not.
@router.get("/", response_model=ToSettleResponse)
async def to_settle(db: DbSession, _: Admin) -> ToSettleResponse:
    rows = await debtors(db, now_in_rome())

    return ToSettleResponse(
        total_cents=sum(row.total_cents for row in rows),
        rows=[
            DebtorResponse(
                tax_code=row.tax_code,
                first_name=row.first_name,
                last_name=row.last_name,
                student=row.student,
                enrolled=row.enrolled,
                roles=list(row.roles),
                since=row.since,
                total_cents=row.total_cents,
                opening_pending=row.opening_pending,
                items=[
                    OwedItemResponse.model_validate(
                        {
                            "kind": item.kind,
                            "cents": item.cents,
                            "minutes": item.minutes,
                            "year": item.year,
                            "first_day": item.first_day,
                            "last_day": item.last_day,
                            "days": list(item.days),
                            "interleaved": item.interleaved,
                            "opening": item.opening,
                            "fee_id": item.fee_id,
                        }
                    )
                    for item in row.items
                ],
            )
            for row in rows
        ],
    )

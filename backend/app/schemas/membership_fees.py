from typing import Final

from pydantic import BaseModel, Field

_MAX_AMOUNT_CENTS: Final[int] = 10_000_000


# One annual fee as the creation wizard asks it: paid today or owed.
class WizardFeeData(BaseModel):
    amount_cents: int = Field(..., gt=0, le=_MAX_AMOUNT_CENTS)
    paid: bool


class WizardFeesData(BaseModel):
    membership: WizardFeeData
    insurance: WizardFeeData

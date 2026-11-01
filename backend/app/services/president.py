from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.administrator import Administrator, AdministratorRoleEnum


# The president may teach, but families neither see nor name them as a teacher.
async def president_tax_code(db: AsyncSession) -> str | None:
    return await db.scalar(
        select(Administrator.tax_code).where(
            Administrator.role == AdministratorRoleEnum.PRESIDENT,
        )
    )

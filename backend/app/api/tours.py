from typing import Annotated, Literal

from fastapi import APIRouter, Query, Response, status
from sqlalchemy import delete, func, or_, select
from sqlalchemy.dialects.postgresql import insert

from app.api.current_account import CurrentAccount
from app.api.dependencies import DbSession
from app.models.seen_tour import SeenTour, TourPlatformEnum
from app.schemas.tour import SeenToursWrite, TourSlug

# Tutorial tours each account has seen, so a tour shows once whatever the device.
router = APIRouter(prefix="/tours", tags=["tours"])

Platform = Literal["mobile", "desktop"]


def _platform(value: Platform) -> TourPlatformEnum:
    return TourPlatformEnum(value.upper())


@router.get("/{platform}")
async def seen_tours(
    platform: Platform,
    current_account: CurrentAccount,
    db: DbSession,
) -> dict[str, int]:
    rows = await db.execute(
        select(SeenTour.slug, SeenTour.version).where(
            SeenTour.account_tax_code == current_account.tax_code,
            SeenTour.platform == _platform(platform),
        ),
    )

    return {slug: version for slug, version in rows.all()}


@router.put("/{platform}", status_code=status.HTTP_204_NO_CONTENT)
async def mark_tours_seen(
    platform: Platform,
    payload: SeenToursWrite,
    current_account: CurrentAccount,
    db: DbSession,
) -> Response:
    if payload.seen:
        statement = insert(SeenTour).values(
            [
                {
                    "account_tax_code": current_account.tax_code,
                    "platform": _platform(platform),
                    "slug": slug,
                    "version": version,
                }
                for slug, version in payload.seen.items()
            ],
        )

        await db.execute(
            statement.on_conflict_do_update(
                index_elements=["account_tax_code", "platform", "slug"],
                set_={
                    "version": func.greatest(
                        SeenTour.version,
                        statement.excluded.version,
                    ),
                    "updated_at": func.now(),
                },
            ),
        )
        await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)


# Tours are slugged by section ("home", "home.teacher"); without one, all are cleared.
@router.delete("/{platform}", status_code=status.HTTP_204_NO_CONTENT)
async def reset_tours(
    platform: Platform,
    current_account: CurrentAccount,
    db: DbSession,
    section: Annotated[list[TourSlug] | None, Query()] = None,
) -> Response:
    statement = delete(SeenTour).where(
        SeenTour.account_tax_code == current_account.tax_code,
        SeenTour.platform == _platform(platform),
    )

    if section:
        statement = statement.where(
            or_(
                *(
                    or_(
                        SeenTour.slug == name,
                        SeenTour.slug.startswith(f"{name}.", autoescape=True),
                    )
                    for name in section
                ),
            ),
        )

    await db.execute(statement)
    await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)

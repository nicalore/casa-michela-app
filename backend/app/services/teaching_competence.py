from collections.abc import Collection

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.booking_window import today_in_rome
from app.models.teacher_service import TeacherService
from app.models.teaching_competence import TeachingCompetence


# Inside a programme only the (discipline, programme) pair counts; outside it, or with
# no programme known, any programme will do. Shared by the calendar and the statistics.
def lacks_competence(
    subject_id: int,
    *,
    programmes: Collection[int],
    within: Collection[int],
    granted: Collection[tuple[int, int]],
    any_programme: Collection[int],
) -> bool:
    if not programmes or subject_id not in within:
        return subject_id not in any_programme

    return any((subject_id, programme) not in granted for programme in programmes)


# Unwanted rows are closed today (deleted if opened today), so past days stay readable.
async def replace_competences(
    db: AsyncSession,
    tax_code: str,
    wanted: Collection[tuple[int, int]],
) -> None:
    today = today_in_rome()
    open_rows = (
        await db.scalars(
            select(TeachingCompetence).where(
                TeachingCompetence.teacher_tax_code == tax_code,
                TeachingCompetence.valid_to.is_(None),
            )
        )
    ).all()
    held = {
        (row.association_subject_id, row.study_program_id): row for row in open_rows
    }

    for key, row in held.items():
        if key in wanted:
            continue

        if row.valid_from == today:
            await db.delete(row)
        else:
            row.valid_to = today

    for subject_id, programme_id in set(wanted) - held.keys():
        db.add(
            TeachingCompetence(
                teacher_tax_code=tax_code,
                association_subject_id=subject_id,
                study_program_id=programme_id,
                valid_from=today,
            )
        )

    await db.flush()


async def replace_services(
    db: AsyncSession,
    tax_code: str,
    wanted: Collection[str],
) -> None:
    today = today_in_rome()
    open_rows = (
        await db.scalars(
            select(TeacherService).where(
                TeacherService.teacher_tax_code == tax_code,
                TeacherService.valid_to.is_(None),
            )
        )
    ).all()
    held = {row.service_name: row for row in open_rows}

    for name, row in held.items():
        if name in wanted:
            continue

        if row.valid_from == today:
            await db.delete(row)
        else:
            row.valid_to = today

    for name in set(wanted) - held.keys():
        db.add(
            TeacherService(
                teacher_tax_code=tax_code,
                service_name=name,
                valid_from=today,
            )
        )

    await db.flush()

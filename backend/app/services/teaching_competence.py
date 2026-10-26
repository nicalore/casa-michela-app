from collections import Counter
from collections.abc import Collection
from datetime import date

from fastapi import HTTPException, status
from sqlalchemy import ColumnElement, Select, func, select, tuple_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.booking_window import today_in_rome
from app.models.ministry_association_subject import MinistryAssociationSubject
from app.models.study_program_subject import StudyProgramSubject
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


# A programme teaches a discipline through a ministry subject linked to both.
def select_teachable_pairs() -> Select[tuple[int, int]]:
    return select(
        MinistryAssociationSubject.association_subject_id,
        StudyProgramSubject.study_program_id,
    ).join(
        StudyProgramSubject,
        StudyProgramSubject.ministry_subject_id
        == MinistryAssociationSubject.ministry_subject_id,
    )


# Teachers whose every standing competence meets `doomed`: deleting it leaves none.
def select_teachers_left_without(doomed: ColumnElement[bool]) -> Select[tuple[str]]:
    return (
        select(TeachingCompetence.teacher_tax_code)
        .where(TeachingCompetence.valid_to.is_(None))
        .group_by(TeachingCompetence.teacher_tax_code)
        .having(func.bool_and(doomed))
    )


# Closed today (deleted if opened today), so past days stay readable.
async def _withdraw(db: AsyncSession, row: TeachingCompetence, today: date) -> None:
    if row.valid_from == today:
        await db.delete(row)
    else:
        row.valid_to = today


async def replace_competences(
    db: AsyncSession,
    tax_code: str,
    wanted: Collection[tuple[int, int]],
) -> None:
    today = today_in_rome()
    subject_ids = {subject_id for subject_id, _ in wanted}
    teachable = await db.execute(
        select_teachable_pairs().where(
            MinistryAssociationSubject.association_subject_id.in_(subject_ids)
        )
    )
    # A page loaded before a catalogue edit may still send pairs it unlinked.
    kept = set(wanted) & {(subject, program) for subject, program in teachable}
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
        if key not in kept:
            await _withdraw(db, row, today)

    for subject_id, programme_id in kept - held.keys():
        db.add(
            TeachingCompetence(
                teacher_tax_code=tax_code,
                association_subject_id=subject_id,
                study_program_id=programme_id,
                valid_from=today,
            )
        )

    await db.flush()


# A catalogue edit can unlink a programme from a discipline: teachers lose that pair,
# unless it was all they had left, which refuses the edit with `refusal`.
async def close_stray_competences(db: AsyncSession, *, refusal: str) -> None:
    # The edit must reach the database before the pairs are read back.
    await db.flush()

    today = today_in_rome()
    stray = (
        await db.scalars(
            select(TeachingCompetence).where(
                TeachingCompetence.valid_to.is_(None),
                tuple_(
                    TeachingCompetence.association_subject_id,
                    TeachingCompetence.study_program_id,
                ).not_in(select_teachable_pairs()),
            )
        )
    ).all()
    lost = Counter(row.teacher_tax_code for row in stray)
    held = await db.execute(
        select(TeachingCompetence.teacher_tax_code, func.count())
        .where(
            TeachingCompetence.valid_to.is_(None),
            TeachingCompetence.teacher_tax_code.in_(list(lost)),
        )
        .group_by(TeachingCompetence.teacher_tax_code)
    )

    if any(lost[tax_code] == count for tax_code, count in held):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=refusal)

    for row in stray:
        await _withdraw(db, row, today)

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

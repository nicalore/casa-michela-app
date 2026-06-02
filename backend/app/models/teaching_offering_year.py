from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Integer,
    event,
    inspect,
    select,
)
from sqlalchemy.orm import (
    Mapped,
    Session,
    mapped_column,
    relationship,
)

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.teaching_offering import (
        EducationLevelEnum,
        TeachingOffering,
    )


class TeachingOfferingYear(Base):
    __tablename__ = "teaching_offering_years"

    __table_args__ = (
        CheckConstraint(
            "year BETWEEN 1 AND 5",
            name="valid_school_year",
        ),
    )

    offering_id: Mapped[int] = mapped_column(
        ForeignKey(
            "teaching_offerings.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    year: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    teaching_offering: Mapped[TeachingOffering] = relationship(
        back_populates="years",
    )


def _years_are_consecutive(years: set[int]) -> bool:
    return max(years) - min(years) + 1 == len(years)


def _validate_years_for_level(
    level: EducationLevelEnum,
    years: set[int],
) -> bool:
    from app.models.teaching_offering import EducationLevelEnum

    if level == EducationLevelEnum.PRIMARY_SCHOOL:
        return years.issubset({1, 2, 3, 4, 5})

    if level == EducationLevelEnum.MIDDLE_SCHOOL:
        return years.issubset({1, 2, 3})

    if level == EducationLevelEnum.HIGH_SCHOOL:
        return years.issubset({1, 2, 3, 4, 5})

    return False


def _effective_offering_id(
    year: TeachingOfferingYear,
) -> int | None:
    if year.offering_id is not None:
        return year.offering_id

    if year.teaching_offering is not None:
        return year.teaching_offering.id

    return None


@event.listens_for(Session, "before_flush")
def _validate_teaching_offering_years(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    from app.models.teaching_offering import TeachingOffering

    affected_offering_ids: set[int] = set()
    affected_offerings: set[TeachingOffering] = set()

    for collection in (
        session.new,
        session.dirty,
        session.deleted,
    ):
        for obj in collection:
            if isinstance(obj, TeachingOfferingYear):
                offering_id = _effective_offering_id(obj)

                if offering_id is not None:
                    affected_offering_ids.add(offering_id)

                state = inspect(obj)

                affected_offering_ids.update(
                    old_id
                    for old_id in state.attrs.offering_id.history.deleted
                    if old_id is not None
                )

                if obj.teaching_offering is not None:
                    affected_offerings.add(
                        obj.teaching_offering
                    )

            elif isinstance(obj, TeachingOffering):
                affected_offerings.add(obj)

    for offering in affected_offerings:
        if offering in session.deleted:
            continue

        years = {
            offering_year.year
            for offering_year in offering.years
            if offering_year not in session.deleted
        }

        if not years:
            raise ValueError(
                "Teaching offering must contain at least one school year"
            )

        if not _years_are_consecutive(years):
            raise ValueError(
                "Teaching offering years must be consecutive"
            )

        if not _validate_years_for_level(
            offering.level,
            years,
        ):
            raise ValueError(
                "Teaching offering years are not valid "
                "for the selected education level"
            )

    with session.no_autoflush:
        for offering_id in affected_offering_ids:
            offering = session.get(
                TeachingOffering,
                offering_id,
            )

            if offering is None:
                continue

            years = set(
                session.scalars(
                    select(
                        TeachingOfferingYear.year,
                    ).where(
                        TeachingOfferingYear.offering_id
                        == offering_id,
                    ),
                ),
            )

            for obj in session.deleted:
                if isinstance(
                    obj,
                    TeachingOfferingYear,
                ):
                    state = inspect(obj)

                    old_years = (
                        state.attrs.year.history.deleted
                        or [obj.year]
                    )

                    old_ids = (
                        state.attrs.offering_id.history.deleted
                        or [_effective_offering_id(obj)]
                    )

                    if offering_id in old_ids:
                        years.difference_update(
                            old_years,
                        )

            for obj in session.dirty:
                if isinstance(
                    obj,
                    TeachingOfferingYear,
                ):
                    state = inspect(obj)

                    old_years = (
                        state.attrs.year.history.deleted
                    )

                    old_ids = (
                        state.attrs.offering_id.history.deleted
                        or [_effective_offering_id(obj)]
                    )

                    if (
                        old_years
                        and offering_id in old_ids
                    ):
                        years.difference_update(
                            old_years,
                        )

            for collection in (
                session.new,
                session.dirty,
            ):
                for obj in collection:
                    if not isinstance(
                        obj,
                        TeachingOfferingYear,
                    ):
                        continue

                    if (
                        _effective_offering_id(obj)
                        == offering_id
                    ):
                        years.add(obj.year)

            if not years:
                raise ValueError(
                    "Teaching offering must contain at least one school year"
                )

            if not _years_are_consecutive(years):
                raise ValueError(
                    "Teaching offering years must be consecutive"
                )

            if not _validate_years_for_level(
                offering.level,
                years,
            ):
                raise ValueError(
                    "Teaching offering years are not valid "
                    "for the selected education level"
                )
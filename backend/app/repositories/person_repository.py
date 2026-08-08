from collections.abc import Iterable

from sqlalchemy import select

from app.models.person import Person
from app.repositories.base import SessionRepository


class PersonRepository(SessionRepository):
    async def get_options(self, tax_codes: Iterable[str]) -> dict[str, Person]:
        tax_codes = {tax_code for tax_code in tax_codes if tax_code is not None}

        if not tax_codes:
            return {}

        rows = await self.session.scalars(
            select(Person).where(Person.tax_code.in_(tax_codes))
        )

        return {person.tax_code: person for person in rows}

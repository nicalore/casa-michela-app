import os
import subprocess
from collections.abc import AsyncIterator
from datetime import date
from pathlib import Path

import psycopg
import pytest
import pytest_asyncio
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.pool import NullPool

from app.api.rbac import IdentityContext
from app.core.config import settings
from app.models.administrator import Administrator
from app.models.member import Member
from app.models.person import Person
from app.models.staff import Staff

BACKEND_DIR = Path(__file__).resolve().parent.parent


def identity_of(
    tax_code: str,
    *roles: str,
    children: tuple[str, ...] = (),
) -> IdentityContext:
    return IdentityContext(
        tax_code=tax_code,
        roles=frozenset(roles),
        child_tax_codes=frozenset(children),
    )


# Band locks FK onto administrators, so this identity must exist as a row;
# _seed_administrator creates it in every test's transaction.
ADMIN_TAX_CODE = "AAAAAA00A01A999E"

ADMIN_IDENTITY = identity_of(ADMIN_TAX_CODE, "ADMIN")

_BASE_URL = make_url(settings.async_database_url)
_TEST_DB = os.environ.get("TEST_POSTGRES_DB", f"{_BASE_URL.database}_test")

TEST_ASYNC_URL = _BASE_URL.set(database=_TEST_DB)
TEST_SYNC_URL = TEST_ASYNC_URL.set(drivername="postgresql+psycopg")


def _create_database_if_missing() -> None:
    # CREATE DATABASE cannot run inside the database it is creating.
    admin_url = _BASE_URL.set(drivername="postgresql", database="postgres")

    with psycopg.connect(
        admin_url.render_as_string(hide_password=False),
        autocommit=True,
    ) as connection:
        exists = connection.execute(
            "SELECT 1 FROM pg_database WHERE datname = %s",
            (_TEST_DB,),
        ).fetchone()

        if exists is None:
            connection.execute(f'CREATE DATABASE "{_TEST_DB}"')


# Dedicated test database; schema built via migrations (not create_all) so
# every run exercises them and matches production exactly.
@pytest.fixture(scope="session", autouse=True)
def _database() -> None:
    _create_database_if_missing()

    subprocess.run(  # noqa: S603
        ["uv", "run", "alembic", "upgrade", "head"],  # noqa: S607
        cwd=BACKEND_DIR,
        check=True,
        capture_output=True,
        env={
            **os.environ,
            "DATABASE_URL": TEST_SYNC_URL.render_as_string(hide_password=False),
        },
    )


# One engine per test: pytest-asyncio gives each test its own event loop, and
# a pooled connection opened in one loop cannot be reused from the next.
@pytest_asyncio.fixture
async def engine(_database: None):
    engine = create_async_engine(
        TEST_ASYNC_URL.render_as_string(hide_password=False),
        echo=False,
        poolclass=NullPool,
    )

    yield engine

    await engine.dispose()


# Outer transaction rolled back per test; create_savepoint makes the services'
# commit() release a savepoint instead of ending the outer transaction.
@pytest_asyncio.fixture
async def db(engine) -> AsyncIterator[AsyncSession]:
    async with engine.connect() as connection:
        transaction = await connection.begin()

        session = AsyncSession(
            bind=connection,
            expire_on_commit=False,
            join_transaction_mode="create_savepoint",
        )

        try:
            await _seed_administrator(session)

            yield session

        finally:
            await session.close()

            if transaction.is_active:
                await transaction.rollback()


async def _seed_administrator(session: AsyncSession) -> None:
    session.add(
        Person(
            tax_code=ADMIN_TAX_CODE,
            first_name="Anna",
            last_name="Bianchi",
            gender="F",
            birth_date=date(2000, 1, 1),
            birth_city="Verona",
            birth_nation="Italia",
            birth_province="VR",
            email="amministrazione@example.com",
            phone="+390000000000",
            residence_type="Via",
            residence_address="Roma",
            residence_street_number="1",
            residence_city="Verona",
            residence_province="VR",
            postal_code="37100",
        ),
    )
    await session.flush()

    session.add(Member(tax_code=ADMIN_TAX_CODE))
    session.add(Staff(tax_code=ADMIN_TAX_CODE, collaboration_type="VOLUNTEER"))
    await session.flush()

    session.add(
        Administrator(
            tax_code=ADMIN_TAX_CODE,
            role="OTHER",
            other_role="Presidenza",
        ),
    )
    await session.flush()

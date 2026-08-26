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


# The identity the services and the RBAC dependency work from. Built by hand
# rather than logged in: what is under test is what the roles let somebody do,
# not how they proved who they are.
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


# Not a bare string any more: taking a calendar band in hand writes down who is
# holding it, and that is a foreign key onto administrators. The identity the
# tests act through has to be somebody who exists — which it always claimed to
# be. _seeded_administrator below is what puts them there.
ADMIN_TAX_CODE = "AAAAAA00A01A999E"

ADMIN_IDENTITY = identity_of(ADMIN_TAX_CODE, "ADMIN")

_BASE_URL = make_url(settings.async_database_url)
_TEST_DB = os.environ.get("TEST_POSTGRES_DB", f"{_BASE_URL.database}_test")

TEST_ASYNC_URL = _BASE_URL.set(database=_TEST_DB)
TEST_SYNC_URL = TEST_ASYNC_URL.set(drivername="postgresql+psycopg")


def _create_database_if_missing() -> None:
    # Connected to the maintenance database, since CREATE DATABASE cannot run
    # inside the database it is creating.
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


# A database of its own, never the development one. The before_flush hooks are
# registered on the Session globally, so a test that fails part-way through
# would otherwise leave rows behind in a database somebody is working in.
#
# The schema is built by running the migrations rather than by create_all: that
# way every run exercises them, which is half of what they are worth. It also
# means a lesson's generated column and the composite keys are exactly what
# production will have.
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


# One engine per test, and deliberately not one per session: pytest-asyncio
# gives each test its own event loop, and a pooled connection opened in one loop
# cannot be used from the next. The cost is a connection per test, which is
# nothing next to the confusion of a suite that passes one test at a time and
# fails when run together.
@pytest_asyncio.fixture
async def engine(_database: None):
    engine = create_async_engine(
        TEST_ASYNC_URL.render_as_string(hide_password=False),
        echo=False,
        poolclass=NullPool,
    )

    yield engine

    await engine.dispose()


# One outer transaction per test, rolled back at the end, so nothing a test
# writes survives it. join_transaction_mode="create_savepoint" is what makes the
# services usable unchanged: their commit() releases a savepoint instead of
# ending the outer transaction.
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


# The person behind ADMIN_IDENTITY, written into every test's transaction and
# rolled back with it. Here and not in the factories because it is not a choice
# a test makes: the identity is a module constant, so the row it names has to be
# there wherever it is used.
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

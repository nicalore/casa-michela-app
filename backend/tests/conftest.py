import os
import subprocess
from collections.abc import AsyncIterator
from pathlib import Path

import psycopg
import pytest
import pytest_asyncio
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.pool import NullPool

from app.api.rbac import IdentityContext
from app.core.config import settings

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


ADMIN_IDENTITY = identity_of("AAAAAA00A01A999X", "ADMIN")

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
            yield session

        finally:
            await session.close()

            if transaction.is_active:
                await transaction.rollback()

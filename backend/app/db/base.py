from typing import Final

from sqlalchemy import MetaData
from sqlalchemy.orm import DeclarativeBase

# The "ck" convention relies on %(constraint_name)s: every CheckConstraint
# must carry an explicit name, otherwise it cannot be rendered.
NAMING_CONVENTION: Final[dict[str, str]] = {
    "ix": "ix_%(table_name)s_%(column_0_name)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

metadata = MetaData(naming_convention=NAMING_CONVENTION)


class Base(DeclarativeBase):
    metadata = metadata
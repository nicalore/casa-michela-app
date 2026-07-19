from typing import Annotated

from pydantic import AfterValidator


def _strip(value: str) -> str:
    return value.strip()


def _strip_to_none(value: str | None) -> str | None:
    if value is None:
        return None

    stripped = value.strip()

    return stripped or None


StrippedStr = Annotated[str, AfterValidator(_strip)]

OptionalCleanStr = Annotated[str | None, AfterValidator(_strip_to_none)]
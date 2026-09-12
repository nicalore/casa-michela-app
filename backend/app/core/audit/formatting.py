from typing import Final

from app.core.audit.rules import AuditEntry

_TIMESTAMP_WIDTH: Final[int] = 29
_ACTOR_WIDTH: Final[int] = 16
# "COURSE_PARTICIPANT" is the longest role code.
_ROLE_WIDTH: Final[int] = 18
OPERATION_WIDTH: Final[int] = 38
_OUTCOME_WIDTH: Final[int] = 7
# The "http" header is wider than any status code.
_STATUS_WIDTH: Final[int] = 4
# Last column: padding it would only leave trailing blanks.
_TARGET_WIDTH: Final[int] = 0

_WIDTHS: Final[tuple[int, ...]] = (
    _TIMESTAMP_WIDTH,
    _ACTOR_WIDTH,
    _ROLE_WIDTH,
    OPERATION_WIDTH,
    _OUTCOME_WIDTH,
    _STATUS_WIDTH,
    _TARGET_WIDTH,
)

_COLUMN_GAP: Final[str] = "  "

EMPTY_VALUE: Final[str] = "-"


# ljust never truncates: an over-long value widens its own row and leaves
# every other row aligned, so reading a column by character offset keeps working.
def _row(values: tuple[str, ...]) -> str:
    padded = (value.ljust(width) for value, width in zip(values, _WIDTHS, strict=True))

    return _COLUMN_GAP.join(padded).rstrip()


AUDIT_HEADER: Final[str] = _row(
    ("timestamp", "actor", "role", "operation", "outcome", "http", "target"),
)


def format_audit_line(entry: AuditEntry) -> str:
    return _row(
        (
            entry.timestamp,
            entry.actor or EMPTY_VALUE,
            entry.role or EMPTY_VALUE,
            entry.operation,
            entry.outcome,
            str(entry.status_code),
            entry.target or EMPTY_VALUE,
        ),
    )

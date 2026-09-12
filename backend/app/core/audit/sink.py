import logging
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Final, TextIO
from zoneinfo import ZoneInfo

from app.core.audit.formatting import AUDIT_HEADER, format_audit_line
from app.core.audit.rules import AuditEntry
from app.core.config import settings

ROME_TIMEZONE: Final[ZoneInfo] = ZoneInfo("Europe/Rome")

_LOGGER_NAME: Final[str] = "audit"

_logger: logging.Logger | None = None


def audit_timestamp() -> str:
    return datetime.now(ROME_TIMEZONE).isoformat(timespec="milliseconds")


class DateRotatingFileHandler(logging.FileHandler):
    def __init__(self, filename_template: str, **kwargs: Any) -> None:
        self.filename_template = filename_template
        super().__init__(self._current_filename(), **kwargs)

    def _current_filename(self) -> str:
        date = datetime.now(ROME_TIMEZONE).strftime("%Y-%m-%d")

        return self.filename_template.format(date=date)

    # Covers both the initial open and the rotation below, since FileHandler
    # sets baseFilename before opening: a new or empty file gets the column
    # header, reopening a populated one after a restart must not repeat it.
    def _open(self) -> TextIO:
        path = Path(self.baseFilename)
        is_new = not path.exists() or path.stat().st_size == 0

        stream = super()._open()

        if is_new:
            stream.write(f"{AUDIT_HEADER}\n")
            stream.flush()

        return stream

    def emit(self, record: logging.LogRecord) -> None:
        filename = os.path.abspath(self._current_filename())

        if self.baseFilename != filename:
            self.close()
            self.baseFilename = filename
            self.stream = self._open()

        super().emit(record)


# Deliberately lazy: nothing touches the filesystem until the first entry, so
# the tests can redirect the sink whatever the import order.
def configure_audit_logger(template: Path | None = None) -> None:
    global _logger

    path = template or settings.audit_log_template
    path.parent.mkdir(parents=True, exist_ok=True)

    logger = logging.getLogger(_LOGGER_NAME)
    logger.setLevel(logging.INFO)
    logger.propagate = False

    for handler in list(logger.handlers):
        logger.removeHandler(handler)
        handler.close()

    file_handler = DateRotatingFileHandler(str(path), encoding="utf-8")
    file_handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(file_handler)

    _logger = logger


def _audit_logger() -> logging.Logger:
    if _logger is None:
        configure_audit_logger()

    return logging.getLogger(_LOGGER_NAME)


def log_audit_entry(entry: AuditEntry) -> None:
    _audit_logger().info(format_audit_line(entry))

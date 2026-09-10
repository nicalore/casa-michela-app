from datetime import date, datetime, time
from typing import Final
from zoneinfo import ZoneInfo

from starlette.concurrency import run_in_threadpool

from app.core.pdf_forms import asset_bytes, fill_acroform, form_field_map
from app.core.storage import (
    EARLY_EXIT_FORM_FIELD_MAP,
    EARLY_EXIT_FORM_TEMPLATE,
    ENROLLMENT_FORM_FONT,
)
from app.schemas.enrollment_form import EnrollmentFormRequest
from app.schemas.person_wizard import PersonWizardPayloadBase

_TIMEZONE: Final[ZoneInfo] = ZoneInfo("Europe/Rome")

_FILE_NAME: Final[str] = "Modulo uscita anticipata {first_name} {last_name} {day}.pdf"

# 1=Monday .. 7=Sunday, per ISO 8601, as the register stores them.
_WEEKDAY_NAMES: Final[tuple[str, ...]] = (
    "lunedì",
    "martedì",
    "mercoledì",
    "giovedì",
    "venerdì",
    "sabato",
    "domenica",
)

# The paper form has two lines of days and nowhere to put a third.
_LINE_PREFIXES: Final[tuple[str, ...]] = ("uscita1", "uscita2")

# Two consecutive days read better named than spanned.
_SHORTEST_RANGE: Final[int] = 3

_RANGE: Final[str] = "{first} - {last}"


def needs_early_exit_form(person: PersonWizardPayloadBase) -> bool:
    """True when the register has an authorised early exit worth printing."""
    student = person.student_data

    return student is not None and student.authorized_early_exit


async def build_early_exit_form(request: EnrollmentFormRequest) -> bytes:
    """Fill a copy of the template with the register's data. Nothing is stored."""
    field_map = form_field_map(EARLY_EXIT_FORM_FIELD_MAP)

    values = early_exit_form_values(
        request,
        today=_today(),
        checked=field_map.checked,
    )

    # Same cost as the enrolment form, so keep it off the event loop too.
    return await run_in_threadpool(
        fill_acroform,
        asset_bytes(EARLY_EXIT_FORM_TEMPLATE),
        field_map.group_by_page(values),
        font=asset_bytes(ENROLLMENT_FORM_FONT),
    )


def early_exit_form_file_name(
    request: EnrollmentFormRequest,
    *,
    today: date | None = None,
) -> str:
    """Download file name for the form."""
    general = request.person.general_data

    return _FILE_NAME.format(
        first_name=general.first_name.strip(),
        last_name=general.last_name.strip(),
        day=f"{today or _today():%d-%m-%Y}",
    )


def early_exit_form_values(
    request: EnrollmentFormRequest,
    *,
    today: date,
    checked: str,
) -> dict[str, str]:
    """Map the register's data onto the template's field names."""
    values: dict[str, str] = {}
    student = request.person.student_data

    if student is None:
        return values

    general = request.person.general_data

    # 'Thiene,' is already printed beside the cell: only the date goes in.
    _text(values, "luogo_data_richiesta", f"{today:%d/%m/%Y}")
    _text(values, "studente_nome", _full_name(general.first_name, general.last_name))

    # The form names one applicant, and the wizard lists parents in the picked order.
    if request.parents:
        applicant = request.parents[0]
        _text(
            values,
            "richiedente_nome",
            _full_name(applicant.first_name, applicant.last_name),
        )

    limited = student.early_exit_start_date is not None
    _tick(values, "periodo_tutta_iscrizione", not limited, checked=checked)
    _tick(values, "periodo_specifico", limited, checked=checked)

    if limited:
        _text(values, "periodo_dal", _day(student.early_exit_start_date))
        _text(values, "periodo_al", _day(student.early_exit_end_date))

    for prefix, schedule in zip(
        _LINE_PREFIXES,
        student.early_exit_schedules,
        strict=False,
    ):
        _text(values, f"{prefix}_giorni", _weekdays(schedule.weekdays))
        _text(values, f"{prefix}_orario", _clock(schedule.exit_time))
        _text(values, f"{prefix}_motivo", schedule.reason)

    return values


def _today() -> date:
    # Local Rome date: a UTC server would date the form a day early.
    return datetime.now(_TIMEZONE).date()


def _full_name(first_name: str | None, last_name: str | None) -> str:
    return " ".join(part.strip() for part in (first_name, last_name) if part)


# Three or more consecutive days collapse into a range; two are spelled out.
def _weekdays(weekdays: list[int]) -> str:
    parts = [
        _RANGE.format(
            first=_WEEKDAY_NAMES[run[0] - 1],
            last=_WEEKDAY_NAMES[run[-1] - 1],
        )
        if len(run) >= _SHORTEST_RANGE
        else ", ".join(_WEEKDAY_NAMES[weekday - 1] for weekday in run)
        for run in _consecutive_runs(sorted(set(weekdays)))
    ]

    return ", ".join(parts).capitalize()


def _consecutive_runs(weekdays: list[int]) -> list[list[int]]:
    runs: list[list[int]] = []

    for weekday in weekdays:
        if runs and weekday == runs[-1][-1] + 1:
            runs[-1].append(weekday)
        else:
            runs.append([weekday])

    return runs


def _clock(value: time) -> str:
    return f"{value:%H:%M}"


def _day(value: date | None) -> str | None:
    return f"{value:%d/%m/%Y}" if value is not None else None


def _text(values: dict[str, str], field: str, value: str | None) -> None:
    if value is None:
        return

    stripped = value.strip()

    if stripped:
        values[field] = stripped


def _tick(values: dict[str, str], field: str, on: bool, *, checked: str) -> None:
    if on:
        values[field] = checked

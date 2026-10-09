import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager, suppress
from typing import Any

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.responses import Response

from app.api import (
    association_subjects,
    auth,
    availabilities,
    bookings,
    calendar_activities,
    calendar_locks,
    calendar_publications,
    calendar_teacher_exclusions,
    courses,
    documents,
    home,
    lesson_requests,
    lessons,
    methodological_notes,
    ministry_subjects,
    notices,
    opening_days,
    people,
    person_accounts,
    presences,
    room_supervisions,
    rooms,
    schools,
    services,
    statistics,
    study_programs,
    support,
    teacher_notes,
    teacher_room_assignments,
    technical_notes,
    weekly_templates,
)
from app.core.config import settings
from app.core.exception_handlers import (
    request_validation_exception_handler,
    value_error_exception_handler,
)
from app.core.storage import PROFILE_IMAGES_DIR, UPLOADS_DIR
from app.middleware import audit_logging_middleware
from app.services.calendar_bootstrap import bootstrap_calendar_on_startup
from app.services.collaboration_sweep import settle_collaborations_after_every_close


# Photos are named after their content: what a URL serves never changes.
class _ImmutableStaticFiles(StaticFiles):
    def file_response(self, *args: Any, **kwargs: Any) -> Response:
        response = super().file_response(*args, **kwargs)
        response.headers["Cache-Control"] = "public, max-age=31536000, immutable"

        return response


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    tasks = (
        asyncio.create_task(bootstrap_calendar_on_startup()),
        asyncio.create_task(settle_collaborations_after_every_close()),
    )

    try:
        yield

    finally:
        for task in tasks:
            task.cancel()

        for task in tasks:
            with suppress(asyncio.CancelledError):
                await task


app = FastAPI(
    title="Casa Michela API",
    version="0.1.0",
    lifespan=lifespan,
    # None drops /docs and /redoc too: they load their assets from CDNs.
    openapi_url="/openapi.json" if settings.debug else None,
)

app.add_exception_handler(ValueError, value_error_exception_handler)
app.add_exception_handler(
    RequestValidationError,
    request_validation_exception_handler,
)

PROFILE_IMAGES_DIR.mkdir(parents=True, exist_ok=True)

app.mount(
    f"/{UPLOADS_DIR.as_posix()}",
    _ImmutableStaticFiles(directory=UPLOADS_DIR),
    name="uploads",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    # A file's own name travels in this header; hidden from the page otherwise.
    expose_headers=["Content-Disposition"],
)

app.middleware("http")(audit_logging_middleware)

# Added last, so outermost: the audit middleware keeps reading plain bodies.
app.add_middleware(GZipMiddleware, minimum_size=1024)

app.include_router(auth.router)
app.include_router(association_subjects.router)
app.include_router(schools.router)
app.include_router(services.router)
app.include_router(courses.router)
app.include_router(study_programs.router)
app.include_router(ministry_subjects.router)
app.include_router(opening_days.router)
app.include_router(people.router)
app.include_router(person_accounts.router)
app.include_router(methodological_notes.router)
app.include_router(technical_notes.router)
app.include_router(teacher_notes.router)
app.include_router(documents.router)
app.include_router(support.router)
app.include_router(statistics.router)
app.include_router(statistics.personal_router)
app.include_router(home.router)
app.include_router(availabilities.router)
app.include_router(presences.router)
app.include_router(bookings.router)
app.include_router(lesson_requests.router)
app.include_router(weekly_templates.router)
app.include_router(rooms.router)
app.include_router(lessons.router)
app.include_router(teacher_room_assignments.router)
app.include_router(room_supervisions.router)
app.include_router(calendar_publications.router)
app.include_router(calendar_locks.router)
app.include_router(calendar_activities.router)
app.include_router(calendar_teacher_exclusions.router)
app.include_router(notices.router)


@app.get("/health")
def health_check() -> dict[str, str]:
    return {
        "status": "ok",
        "environment": settings.environment,
        "app_name": settings.app_name,
    }

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api import (
    association_subjects,
    auth,
    availabilities,
    bookings,
    lesson_requests,
    ministry_subjects,
    opening_days,
    people,
    presences,
    schools,
    services,
    statistics,
    study_programs,
    weekly_templates,
)
from app.core.config import settings
from app.core.exception_handlers import value_error_exception_handler
from app.core.storage import PROFILE_IMAGES_DIR, UPLOADS_DIR
from app.middleware import audit_logging_middleware

app = FastAPI(
    title="Casa Michela API",
    version="0.1.0",
)

app.add_exception_handler(ValueError, value_error_exception_handler)

PROFILE_IMAGES_DIR.mkdir(parents=True, exist_ok=True)

app.mount(
    f"/{UPLOADS_DIR.as_posix()}",
    StaticFiles(directory=UPLOADS_DIR),
    name="uploads",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.middleware("http")(audit_logging_middleware)

app.include_router(auth.router)
app.include_router(association_subjects.router)
app.include_router(schools.router)
app.include_router(services.router)
app.include_router(study_programs.router)
app.include_router(ministry_subjects.router)
app.include_router(opening_days.router)
app.include_router(people.router)
app.include_router(statistics.router)
app.include_router(availabilities.router)
app.include_router(presences.router)
app.include_router(bookings.router)
app.include_router(lesson_requests.router)
app.include_router(weekly_templates.router)


@app.get("/health")
def health_check() -> dict[str, str]:
    return {
        "status": "ok",
        "environment": settings.environment,
        "app_name": settings.app_name,
    }

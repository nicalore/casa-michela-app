import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api import (
    association_subjects,
    ministry_subjects,
    people,
    schools,
    study_programs,
)
from app.api.auth import router as auth_router
from app.core.config import settings

app = FastAPI(
    title="Casa Michela API",
    version="0.1.0",
)

app.mount(
    "/uploads",
    StaticFiles(
        directory="uploads",
    ),
    name="uploads",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(association_subjects.router)
app.include_router(schools.router)
app.include_router(study_programs.router)
app.include_router(ministry_subjects.router)
app.include_router(people.router, prefix="/people", tags=["people"])

os.makedirs("uploads/profile-images", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "environment": settings.environment,
        "app_name": settings.app_name,
    }

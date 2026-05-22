from fastapi import FastAPI
from app.core.config import settings
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Casa Michela API",
    version="0.1.0"
)

origins = settings.cors_origins.split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://localhost:\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "environment": settings.environment,
        "app_name": settings.app_name,
    }

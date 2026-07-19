from pathlib import Path
from typing import Final

from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url

_ENV_FILE: Final[Path] = Path(__file__).resolve().parents[2] / ".env"

_REQUIRED_DATABASE_FIELDS: Final[tuple[str, ...]] = (
    "postgres_host",
    "postgres_port",
    "postgres_db",
    "postgres_user",
    "postgres_password",
)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=_ENV_FILE,
        extra="ignore",
    )

    app_name: str = "Casa Michela API"
    environment: str = "development"
    debug: bool = False
    cors_origins: str = "http://localhost:3000"

    database_url: str | None = None
    postgres_host: str | None = None
    postgres_port: int | None = None
    postgres_db: str | None = None
    postgres_user: str | None = None
    postgres_password: str | None = None

    jwt_access_secret: str = "CHANGE_ME_ACCESS"
    jwt_refresh_secret: str = "CHANGE_ME_REFRESH"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 30
    max_failed_login_attempts: int = 5
    failed_login_reset_minutes: int = 30
    account_lock_minutes: int = 20

    resend_api_key: str | None = None
    frontend_url: str = "http://localhost:3000"

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",")]

    def sqlalchemy_database_url(self, drivername: str) -> str:
        # A full database_url takes precedence over the single postgres_*
        # fields: only its driver is replaced with the requested one.
        if self.database_url:
            return (
                make_url(self.database_url)
                .set(drivername=drivername)
                .render_as_string(hide_password=False)
            )

        missing = [
            name for name in _REQUIRED_DATABASE_FIELDS if getattr(self, name) is None
        ]

        if missing:
            raise ValueError(
                "Configurazione del database mancante: "
                f"{', '.join(missing)} oppure database_url"
            )

        return URL.create(
            drivername=drivername,
            username=self.postgres_user,
            password=self.postgres_password,
            host=self.postgres_host,
            port=self.postgres_port,
            database=self.postgres_db,
        ).render_as_string(hide_password=False)

    @property
    def async_database_url(self) -> str:
        return self.sqlalchemy_database_url("postgresql+asyncpg")

    @property
    def sync_database_url(self) -> str:
        return self.sqlalchemy_database_url("postgresql+psycopg")


settings = Settings()
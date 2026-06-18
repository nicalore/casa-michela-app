from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url


class Settings(BaseSettings):
    app_name: str = "Casa Michela API"
    environment: str = "development"
    debug: bool = False
    cors_origins: str = "http://localhost:3000"

    #DatabaseConfig
    database_url: str | None = None
    postgres_host: str | None = None
    postgres_port: int | None = None
    postgres_db: str | None = None
    postgres_user: str | None = None
    postgres_password: str | None = None

    #AuthConfig
    jwt_access_secret: str = "CHANGE_ME_ACCESS"
    jwt_refresh_secret: str = "CHANGE_ME_REFRESH"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 1
    refresh_token_expire_days: int = 30
    max_failed_login_attempts: int = 5
    failed_login_reset_minutes: int = 30
    account_lock_minutes: int = 20

    #EmailRecoveryConfig
    resend_api_key: str | None = None
    frontend_url: str = "http://localhost:3000"

    @property
    def cors_origins_list(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.cors_origins.split(",")
        ]

    def sqlalchemy_database_url(self, drivername: str) -> str:
        if self.database_url:
            return make_url(self.database_url).set(
                drivername=drivername
            ).render_as_string(
                hide_password=False
            )

        missing = [
            name
            for name in (
                "postgres_host",
                "postgres_port",
                "postgres_db",
                "postgres_user",
                "postgres_password",
            )
            if getattr(self, name) is None
        ]

        if missing:
            raise ValueError(
                "Missing database configuration: "
                f"{', '.join(missing)} or database_url"
            )

        return URL.create(
            drivername=drivername,
            username=self.postgres_user,
            password=self.postgres_password,
            host=self.postgres_host,
            port=self.postgres_port,
            database=self.postgres_db,
        ).render_as_string(
            hide_password=False
        )

    @property
    def async_database_url(self) -> str:
        return self.sqlalchemy_database_url(
            "postgresql+asyncpg"
        )

    @property
    def sync_database_url(self) -> str:
        return self.sqlalchemy_database_url(
            "postgresql+psycopg"
        )

    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[2] / ".env",
        extra="ignore",
    )

settings = Settings()
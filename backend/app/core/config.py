from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url


class Settings(BaseSettings):
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

    @property
    def cors_origins_list(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.cors_origins.split(",")
        ]

    def sqlalchemy_database_url(self, drivername: str) -> str:
        if self.database_url:
            return make_url(self.database_url).set(drivername=drivername).render_as_string(
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
        ).render_as_string(hide_password=False)

    @property
    def async_database_url(self) -> str:
        return self.sqlalchemy_database_url("postgresql+asyncpg")

    @property
    def sync_database_url(self) -> str:
        return self.sqlalchemy_database_url("postgresql+psycopg")

    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[2] / ".env",
        extra="ignore",
    )


settings = Settings()

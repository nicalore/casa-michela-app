from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Casa Michela API"

    environment: str = "development"

    debug: bool = False

    api_host: str = "0.0.0.0"
    api_port: int = 8000

    postgres_host: str
    postgres_port: int
    postgres_db: str
    postgres_user: str
    postgres_password: str

    database_url: str

    secret_key: str

    cors_origins: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=False,
    )


settings = Settings()

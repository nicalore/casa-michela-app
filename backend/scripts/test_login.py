import asyncio

from app.core.database import (
    AsyncSessionLocal,
)
from app.repositories.account_repository import (
    AccountRepository,
)
from app.repositories.refresh_token_repository import (
    RefreshTokenRepository,
)
from app.services.auth_service import (
    AccountDisabledError,
    AccountLockedError,
    AuthenticationError,
    AuthService,
)


async def main() -> None:
    username = input(
        "Username: "
    ).strip()

    password = input(
        "Password: "
    ).strip()

    async with AsyncSessionLocal() as session:
        account_repository = (
            AccountRepository(
                session
            )
        )

        refresh_token_repository = (
            RefreshTokenRepository(
                session
            )
        )

        auth_service = AuthService(
            account_repository=account_repository,
            refresh_token_repository=refresh_token_repository,
        )

        try:
            result = (
                await auth_service.authenticate(
                    username=username,
                    password=password,
                )
            )

            print(
                "\nLogin riuscito"
            )

            print(
                "Password reset richiesto: "
                f"{result.password_reset_required}"
            )

            print(
                "\nAccess token:"
            )

            print(result.access_token)

            print(
                "\nRefresh token:"
            )

            print(result.refresh_token)

        except AccountLockedError as exc:
            print(
                "\nAccount temporaneamente "
                "bloccato fino a:"
            )

            print(exc.locked_until)

        except AccountDisabledError:
            print(
                "\nAccount disabilitato"
            )

        except AuthenticationError:
            print(
                "\nUsername o password "
                "non validi"
            )


if __name__ == "__main__":
    asyncio.run(main())
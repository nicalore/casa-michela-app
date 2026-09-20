from dataclasses import dataclass
from enum import StrEnum
from typing import Final

SUCCESS_OUTCOME: Final[str] = "Success"
FAILURE_OUTCOME: Final[str] = "Failure"


# Actor source without a bearer token: only the auth routes, where nobody is identified.
class ActorSource(StrEnum):
    BODY_USERNAME = "body_username"
    BODY_REFRESH_TOKEN = "body_refresh_token"
    BODY_RESET_TOKEN = "body_reset_token"


@dataclass(frozen=True, slots=True)
class AuditRule:
    operation: str
    # Named path parameters, joined with "/" when there is more than one.
    path_params: tuple[str, ...] = ()
    response_field: str = ""
    # Read from the request so a failed write still says what was attempted; dotted ok.
    body_fields: tuple[str, ...] = ()
    actor_fallback: ActorSource | None = None


# Published on the request scope by the endpoint, so the middleware trusts no raw token.
@dataclass(frozen=True, slots=True)
class AuditActor:
    tax_code: str
    role: str


@dataclass(frozen=True, slots=True)
class AuditEntry:
    timestamp: str
    actor: str
    role: str
    operation: str
    outcome: str
    status_code: int
    target: str

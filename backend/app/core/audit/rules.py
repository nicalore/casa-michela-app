from dataclasses import dataclass
from enum import StrEnum
from typing import Final

SUCCESS_OUTCOME: Final[str] = "Success"
FAILURE_OUTCOME: Final[str] = "Failure"


# Where the actor comes from when the request carries no bearer token: only
# the auth routes, whose whole point is that the caller is not yet identified.
class ActorSource(StrEnum):
    BODY_USERNAME = "body_username"
    BODY_REFRESH_TOKEN = "body_refresh_token"
    BODY_RESET_TOKEN = "body_reset_token"


@dataclass(frozen=True, slots=True)
class AuditRule:
    operation: str
    # Named path parameters, joined with "/" when a route identifies its
    # target with more than one.
    path_params: tuple[str, ...] = ()
    response_field: str = ""
    # Read from the request, so a failed write still says what was attempted.
    # Dotted paths are supported, e.g. "person.general_data.tax_code".
    body_fields: tuple[str, ...] = ()
    actor_fallback: ActorSource | None = None


# What an endpoint publishes on the request scope once it has resolved a
# verified identity, so the middleware need not trust the raw token.
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

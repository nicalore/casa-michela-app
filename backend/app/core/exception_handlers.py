from typing import Final

from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.core.validation_messages import humanize_validation_errors

_VALIDATION_STATUS: Final[int] = 422


# Registered for ValueError only, but the annotation has to stay Exception:
# narrowing it breaks contravariance with Starlette's handler protocol.
async def value_error_exception_handler(
    _request: Request, exc: Exception
) -> JSONResponse:
    return JSONResponse(status_code=400, content={"detail": str(exc)})


async def request_validation_exception_handler(
    _request: Request, exc: Exception
) -> JSONResponse:
    if not isinstance(exc, RequestValidationError):
        raise exc

    return JSONResponse(
        status_code=_VALIDATION_STATUS,
        content={"detail": humanize_validation_errors(exc.errors())},
    )

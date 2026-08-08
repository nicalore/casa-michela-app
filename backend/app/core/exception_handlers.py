from fastapi import Request
from fastapi.responses import JSONResponse


# Registered for ValueError only, so exc is always one at runtime — but the
# annotation has to stay Exception: Starlette's ExceptionHandler protocol hands
# every handler an Exception, and narrowing the parameter breaks contravariance
# (a handler accepting only ValueError is not a valid handler of Exception).
async def value_error_exception_handler(
    _request: Request, exc: Exception
) -> JSONResponse:
    return JSONResponse(status_code=400, content={"detail": str(exc)})

import json
from typing import Any

from app.core.audit.rules import AuditRule

_TARGET_SEPARATOR = "/"


def _nested(payload: dict[str, Any], dotted: str) -> Any:
    value: Any = payload

    for key in dotted.split("."):
        if not isinstance(value, dict):
            return None

        value = value.get(key)

    return value


def _joined(values: list[str]) -> str:
    return _TARGET_SEPARATOR.join(values) if values else ""


def decode_payload(body: bytes) -> dict[str, Any]:
    try:
        payload = json.loads(body)

    except Exception:
        return {}

    return payload if isinstance(payload, dict) else {}


def resolve_target(
    rule: AuditRule,
    path_params: dict[str, Any],
    response_body: bytes,
    payload: dict[str, Any],
) -> str:
    from_path = [
        str(path_params[name]) for name in rule.path_params if name in path_params
    ]

    if from_path:
        return _joined(from_path)

    if rule.response_field:
        response = decode_payload(response_body)
        value = response.get(rule.response_field)

        if value not in (None, ""):
            return str(value)

    # Last resort, and the only one a failed creation has: what was attempted.
    from_body = [
        str(value)
        for value in (_nested(payload, name) for name in rule.body_fields)
        if value not in (None, "")
    ]

    return _joined(from_body)

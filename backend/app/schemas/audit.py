from pydantic import BaseModel


class AuditLogSchema(BaseModel):
    user_id: str
    operation_type: str
    timestamp: str
    status: str
    target: str | None = None
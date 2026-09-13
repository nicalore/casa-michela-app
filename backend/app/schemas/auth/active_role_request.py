from pydantic import BaseModel


class ActiveRoleRequest(BaseModel):
    role: str

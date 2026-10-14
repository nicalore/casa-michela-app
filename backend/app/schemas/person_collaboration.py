from pydantic import BaseModel


class CollaborationUpdate(BaseModel):
    active: bool
    # Switching off drops the hours ahead; without it the server reports them first.
    confirm: bool = False

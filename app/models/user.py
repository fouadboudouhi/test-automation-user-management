from pydantic import BaseModel, EmailStr
from uuid import UUID

class User(BaseModel):
    id: UUID
    email: EmailStr
    name: str
    is_active: bool = True

import uuid
from datetime import date

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    name: str
    age: int = Field(gt=0)
    sex: str
    height_cm: float = Field(gt=0)
    weight_kg: float = Field(gt=0)
    fitness_level: str
    primary_goal: str
    training_frequency: str
    available_equipment: str = ""
    limitations: str = ""


class UserResponse(BaseModel):
    email: EmailStr
    name: str
    age: int
    sex: str
    height_cm: float
    weight_kg: float
    fitness_level: str
    primary_goal: str
    training_frequency: str
    available_equipment: str
    limitations: str

    model_config = {"from_attributes": True}


class UserProfileResponse(BaseModel):
    id: uuid.UUID
    email: EmailStr
    name: str | None
    age: int | None
    sex: str | None
    height_cm: float | None
    weight_kg: float | None
    fitness_level: str | None
    primary_goal: str | None
    training_frequency: str | None
    available_equipment: str | None
    limitations: str | None
    created_at: date | None
    updated_at: date | None

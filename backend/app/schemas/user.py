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

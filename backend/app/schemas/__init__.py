from app.schemas.auth import LoginRequest, TokenResponse
from app.schemas.program import (
    ProgramCreate,
    ProgramExerciseCreate,
    ProgramExerciseResponse,
    ProgramGenerateRequest,
    ProgramResponse,
    ProgramSuggestNextRequest,
    ProgramSuggestNextResponse,
)
from app.schemas.session import (
    SessionCreate,
    SessionExerciseCreate,
    SessionExerciseResponse,
    SessionResponse,
)
from app.schemas.user import (
    UserCreate,
    UserProfileResponse,
    UserProfileUpdate,
    UserResponse,
)

__all__ = [
    "LoginRequest",
    "TokenResponse",
    "UserCreate",
    "UserResponse",
    "UserProfileResponse",
    "UserProfileUpdate",
    "SessionCreate",
    "SessionExerciseCreate",
    "SessionExerciseResponse",
    "SessionResponse",
    "ProgramCreate",
    "ProgramExerciseCreate",
    "ProgramExerciseResponse",
    "ProgramGenerateRequest",
    "ProgramResponse",
    "ProgramSuggestNextRequest",
    "ProgramSuggestNextResponse",
]

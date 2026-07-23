import os
import sys
import uuid
from datetime import date
from unittest.mock import AsyncMock, MagicMock

# Required before importing app.core.config / app.db
os.environ.setdefault(
    "DATABASE_URL",
    "postgresql+asyncpg://fitness:test@localhost:5432/fitness_coach",
)
os.environ.setdefault("SECRET_KEY", "test-secret-key-not-for-production")

# Stub heavy AI optional deps so importing routers does not require them in unit tests.
sys.modules.setdefault("fastembed", MagicMock())

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.core.deps import get_current_user
from app.db import get_db
from app.models.user import User, UserProfile
from app.routers import users


@pytest.fixture
def user_id() -> uuid.UUID:
    return uuid.uuid4()


@pytest.fixture
def profile(user_id: uuid.UUID) -> UserProfile:
    return UserProfile(
        id=uuid.uuid4(),
        user_id=user_id,
        name="Alex",
        age=28,
        sex="female",
        height_cm=170.0,
        weight_kg=65.0,
        fitness_level="intermediate",
        primary_goal="strength",
        training_frequency="3x/week",
        available_equipment="dumbbells",
        limitations="none",
        available_time_minutes=None,
        created_at=date(2026, 1, 1),
        updated_at=date(2026, 1, 1),
    )


@pytest.fixture
def current_user(user_id: uuid.UUID, profile: UserProfile) -> User:
    user = User(
        id=user_id,
        email="alex@example.com",
        hashed_password="hashed",
    )
    user.profile = profile
    return user


@pytest.fixture
def app(current_user: User) -> FastAPI:
    test_app = FastAPI()
    test_app.include_router(users.router, prefix="/api")

    mock_db = AsyncMock()

    async def override_get_db():
        yield mock_db

    async def override_get_current_user():
        return current_user

    def _execute_side_effect(*_args, **_kwargs):
        result = MagicMock()
        result.scalar_one.return_value = current_user
        return result

    mock_db.execute = AsyncMock(side_effect=_execute_side_effect)
    mock_db.commit = AsyncMock()
    mock_db.rollback = AsyncMock()

    test_app.dependency_overrides[get_db] = override_get_db
    test_app.dependency_overrides[get_current_user] = override_get_current_user
    test_app.state.mock_db = mock_db  # type: ignore[attr-defined]
    return test_app


@pytest.fixture
async def client(app: FastAPI):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def unauthenticated_app() -> FastAPI:
    test_app = FastAPI()
    test_app.include_router(users.router, prefix="/api")
    return test_app


@pytest.fixture
async def unauthenticated_client(unauthenticated_app: FastAPI):
    transport = ASGITransport(app=unauthenticated_app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as ac:
        yield ac

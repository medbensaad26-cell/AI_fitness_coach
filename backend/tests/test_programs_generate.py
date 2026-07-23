import uuid
from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.core.deps import get_current_user
from app.db import get_db
from app.models.program import Program
from app.models.user import User
from app.routers import programs
from app.schemas.program import ProgramCreate, ProgramExerciseCreate


@pytest.fixture
def sample_program_create() -> ProgramCreate:
    return ProgramCreate(
        name="Strength Session",
        goal="strength",
        start_date=date(2026, 7, 23),
        end_date=date(2026, 7, 30),
        status="active",
        exercises=[
            ProgramExerciseCreate(
                exercise_name="Goblet Squat",
                sets=3,
                reps="8-10",
                rest_seconds=90,
                duration_minutes=None,
                notes="[id:goblet_squat] Brace core",
                order=0,
            )
        ],
    )


@pytest.fixture
def programs_app(current_user: User):
    test_app = FastAPI()
    test_app.include_router(programs.router, prefix="/api")

    mock_db = AsyncMock()
    added: list[Program] = []

    def add_side_effect(obj):
        if isinstance(obj, Program):
            if obj.id is None:
                obj.id = uuid.uuid4()
            for exercise in obj.exercises:
                if getattr(exercise, "id", None) is None:
                    exercise.id = uuid.uuid4()
                exercise.program_id = obj.id
            added.append(obj)

    execute_calls = {"n": 0}

    async def execute_side_effect(*_args, **_kwargs):
        execute_calls["n"] += 1
        result = MagicMock()
        if execute_calls["n"] == 1:
            result.scalar_one.return_value = current_user
        else:
            result.scalar_one.return_value = added[-1]
        return result

    mock_db.add = MagicMock(side_effect=add_side_effect)
    mock_db.execute = AsyncMock(side_effect=execute_side_effect)
    mock_db.commit = AsyncMock()
    mock_db.rollback = AsyncMock()

    async def override_get_db():
        yield mock_db

    async def override_get_current_user():
        return current_user

    test_app.dependency_overrides[get_db] = override_get_db
    test_app.dependency_overrides[get_current_user] = override_get_current_user
    test_app.state.mock_db = mock_db  # type: ignore[attr-defined]
    test_app.state.added_programs = added  # type: ignore[attr-defined]
    return test_app


@pytest.fixture
async def programs_client(programs_app: FastAPI):
    transport = ASGITransport(app=programs_app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def unauthenticated_programs_app() -> FastAPI:
    test_app = FastAPI()
    test_app.include_router(programs.router, prefix="/api")
    return test_app


@pytest.fixture
async def unauthenticated_programs_client(unauthenticated_programs_app: FastAPI):
    transport = ASGITransport(app=unauthenticated_programs_app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as ac:
        yield ac


@pytest.mark.asyncio
async def test_generate_program_success(
    programs_client, programs_app, current_user, sample_program_create
):
    with patch(
        "app.ai.generate_program.generate_program",
        new_callable=AsyncMock,
        return_value=sample_program_create,
    ) as mock_generate:
        response = await programs_client.post("/api/programs/generate", json={})

    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Strength Session"
    assert data["user_id"] == str(current_user.id)
    assert len(data["exercises"]) == 1
    assert data["exercises"][0]["exercise_name"] == "Goblet Squat"
    mock_generate.assert_awaited_once()
    assert mock_generate.await_args.kwargs["user_id"] == current_user.id
    programs_app.state.mock_db.commit.assert_awaited()


@pytest.mark.asyncio
async def test_generate_program_unauthenticated(unauthenticated_programs_client):
    response = await unauthenticated_programs_client.post(
        "/api/programs/generate", json={}
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_generate_program_incomplete_profile(
    programs_client, programs_app, current_user
):
    current_user.profile.fitness_level = None

    with patch(
        "app.ai.generate_program.generate_program",
        new_callable=AsyncMock,
    ) as mock_generate:
        response = await programs_client.post("/api/programs/generate", json={})

    assert response.status_code == 400
    assert response.json()["detail"] == "Incomplete profile"
    mock_generate.assert_not_awaited()
    programs_app.state.mock_db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_generate_program_invalid_ai_output(programs_client, programs_app):
    with patch(
        "app.ai.generate_program.generate_program",
        new_callable=AsyncMock,
        return_value={"name": "Only name"},
    ):
        response = await programs_client.post("/api/programs/generate", json={})

    assert response.status_code == 502
    assert response.json()["detail"] == "Invalid program generated"
    programs_app.state.mock_db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_generate_program_ai_service_exception(programs_client, programs_app):
    with patch(
        "app.ai.generate_program.generate_program",
        new_callable=AsyncMock,
        side_effect=RuntimeError("Model returned invalid program JSON"),
    ):
        response = await programs_client.post("/api/programs/generate", json={})

    assert response.status_code == 502
    assert response.json()["detail"] == "Program generation failed"
    assert "invalid program JSON" not in response.text
    programs_app.state.mock_db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_generate_program_database_rollback(
    programs_client, programs_app, sample_program_create
):
    programs_app.state.mock_db.commit.side_effect = Exception("db failure")

    with patch(
        "app.ai.generate_program.generate_program",
        new_callable=AsyncMock,
        return_value=sample_program_create,
    ):
        response = await programs_client.post("/api/programs/generate", json={})

    assert response.status_code == 500
    assert response.json()["detail"] == "Failed to create program"
    assert "db failure" not in response.text
    programs_app.state.mock_db.rollback.assert_awaited()


@pytest.mark.asyncio
async def test_generate_program_persisted_ownership(
    programs_client, programs_app, current_user, sample_program_create
):
    with patch(
        "app.ai.generate_program.generate_program",
        new_callable=AsyncMock,
        return_value=sample_program_create,
    ):
        response = await programs_client.post("/api/programs/generate", json={})

    assert response.status_code == 201
    assert len(programs_app.state.added_programs) == 1
    persisted = programs_app.state.added_programs[0]
    assert persisted.user_id == current_user.id
    assert response.json()["user_id"] == str(current_user.id)

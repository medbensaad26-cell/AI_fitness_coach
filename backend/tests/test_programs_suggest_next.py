import uuid
from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.ai.suggest_next import SuggestNextOutput
from app.core.deps import get_current_user
from app.db import get_db
from app.models.program import Program
from app.models.user import User
from app.routers import programs
from app.schemas.program import ProgramCreate, ProgramExerciseCreate


@pytest.fixture
def sample_program_create() -> ProgramCreate:
    return ProgramCreate(
        name="Next Strength Session",
        goal="strength",
        start_date=date(2026, 7, 24),
        end_date=date(2026, 7, 31),
        status="active",
        exercises=[
            ProgramExerciseCreate(
                exercise_name="Romanian Deadlift",
                sets=3,
                reps="8-10",
                rest_seconds=120,
                duration_minutes=None,
                notes="[id:romanian_deadlift] Soft knees",
                order=0,
            )
        ],
    )


@pytest.fixture
def sample_suggest_output(sample_program_create: ProgramCreate) -> SuggestNextOutput:
    return SuggestNextOutput(
        program=sample_program_create,
        rationale="Progress from last session with slightly higher volume.",
        adaptations=["Added RDL", "Reduced fatigue-sensitive volume"],
    )


@pytest.fixture
def suggest_app(current_user: User):
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
            # Load user + profile
            result.scalar_one.return_value = current_user
        else:
            # Reload persisted program
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
    test_app.state.execute_calls = execute_calls  # type: ignore[attr-defined]
    return test_app


@pytest.fixture
async def suggest_client(suggest_app: FastAPI):
    transport = ASGITransport(app=suggest_app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def unauthenticated_suggest_app() -> FastAPI:
    test_app = FastAPI()
    test_app.include_router(programs.router, prefix="/api")
    return test_app


@pytest.fixture
async def unauthenticated_suggest_client(unauthenticated_suggest_app: FastAPI):
    transport = ASGITransport(app=unauthenticated_suggest_app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as ac:
        yield ac


@pytest.mark.asyncio
async def test_suggest_next_success(
    suggest_client, suggest_app, current_user, sample_suggest_output
):
    with patch(
        "app.ai.suggest_next.suggest_next_program",
        new_callable=AsyncMock,
        return_value=sample_suggest_output,
    ) as mock_suggest:
        response = await suggest_client.post(
            "/api/programs/suggest-next", json={}
        )

    assert response.status_code == 201
    data = response.json()
    assert data["program"]["name"] == "Next Strength Session"
    assert data["program"]["user_id"] == str(current_user.id)
    assert data["rationale"].startswith("Progress from last session")
    assert data["adaptations"] == [
        "Added RDL",
        "Reduced fatigue-sensitive volume",
    ]
    mock_suggest.assert_awaited_once()
    assert mock_suggest.await_args.args[2] == current_user.id
    suggest_app.state.mock_db.commit.assert_awaited()


@pytest.mark.asyncio
async def test_suggest_next_user_history_isolation(
    suggest_client, current_user, sample_suggest_output
):
    foreign_user_id = uuid.uuid4()
    with patch(
        "app.ai.suggest_next.suggest_next_program",
        new_callable=AsyncMock,
        return_value=sample_suggest_output,
    ) as mock_suggest:
        response = await suggest_client.post(
            "/api/programs/suggest-next",
            json={"user_id": str(foreign_user_id)},
        )

    assert response.status_code == 201
    assert mock_suggest.await_args.args[2] == current_user.id
    assert mock_suggest.await_args.args[2] != foreign_user_id
    assert response.json()["program"]["user_id"] == str(current_user.id)


@pytest.mark.asyncio
async def test_suggest_next_unauthenticated(unauthenticated_suggest_client):
    response = await unauthenticated_suggest_client.post(
        "/api/programs/suggest-next", json={}
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_suggest_next_no_history(
    suggest_client, suggest_app, sample_suggest_output
):
    with patch(
        "app.ai.suggest_next.suggest_next_program",
        new_callable=AsyncMock,
        return_value=sample_suggest_output,
    ) as mock_suggest:
        response = await suggest_client.post(
            "/api/programs/suggest-next", json={}
        )

    assert response.status_code == 201
    mock_suggest.assert_awaited_once()
    # Router only loads profile then reloads program (AI owns history retrieval).
    assert suggest_app.state.execute_calls["n"] == 2
    suggest_app.state.mock_db.commit.assert_awaited()


@pytest.mark.asyncio
async def test_suggest_next_ai_failure(suggest_client, suggest_app):
    with patch(
        "app.ai.suggest_next.suggest_next_program",
        new_callable=AsyncMock,
        side_effect=RuntimeError("Model returned invalid suggest-next JSON"),
    ):
        response = await suggest_client.post(
            "/api/programs/suggest-next", json={}
        )

    assert response.status_code == 502
    assert response.json()["detail"] == "Program suggestion failed"
    assert "suggest-next JSON" not in response.text
    suggest_app.state.mock_db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_suggest_next_invalid_ai_output(suggest_client, suggest_app):
    with patch(
        "app.ai.suggest_next.suggest_next_program",
        new_callable=AsyncMock,
        return_value=MagicMock(),
    ):
        response = await suggest_client.post(
            "/api/programs/suggest-next", json={}
        )

    assert response.status_code == 502
    assert response.json()["detail"] == "Invalid program suggestion"
    suggest_app.state.mock_db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_suggest_next_persistence_and_ownership(
    suggest_client, suggest_app, current_user, sample_suggest_output
):
    with patch(
        "app.ai.suggest_next.suggest_next_program",
        new_callable=AsyncMock,
        return_value=sample_suggest_output,
    ):
        response = await suggest_client.post(
            "/api/programs/suggest-next", json={}
        )

    assert response.status_code == 201
    assert len(suggest_app.state.added_programs) == 1
    persisted = suggest_app.state.added_programs[0]
    assert persisted.user_id == current_user.id
    assert response.json()["program"]["user_id"] == str(current_user.id)
    assert len(persisted.exercises) == 1

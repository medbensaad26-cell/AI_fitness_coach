import uuid
from datetime import datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.core.deps import get_current_user
from app.db import get_db
from app.models.program import Program, ProgramExercise
from app.models.session import Session
from app.models.user import User
from app.routers import sessions


def _owned_program(user_id: uuid.UUID) -> Program:
    program_id = uuid.uuid4()
    return Program(
        id=program_id,
        user_id=user_id,
        name="Push Day",
        goal="strength",
        start_date=datetime(2026, 7, 1).date(),
        end_date=None,
        status="active",
        exercises=[
            ProgramExercise(
                id=uuid.uuid4(),
                program_id=program_id,
                exercise_name="Goblet Squat",
                sets=3,
                reps="10",
                rest_seconds=90,
                duration_minutes=None,
                notes=None,
                order=0,
            ),
            ProgramExercise(
                id=uuid.uuid4(),
                program_id=program_id,
                exercise_name="Push-Up",
                sets=3,
                reps="12",
                rest_seconds=60,
                duration_minutes=None,
                notes=None,
                order=1,
            ),
        ],
    )


@pytest.fixture
def sessions_app(current_user: User):
    test_app = FastAPI()
    test_app.include_router(sessions.router, prefix="/api")

    mock_db = AsyncMock()
    owned_program = _owned_program(current_user.id)
    foreign_program = _owned_program(uuid.uuid4())
    added_sessions: list[Session] = []
    execute_mode = {"value": "create_owned"}
    execute_calls = {"n": 0}

    def add_side_effect(obj):
        if isinstance(obj, Session):
            if obj.id is None:
                obj.id = uuid.uuid4()
            if obj.created_at is None:
                obj.created_at = datetime.utcnow()
            for exercise in obj.exercises:
                if getattr(exercise, "id", None) is None:
                    exercise.id = uuid.uuid4()
                exercise.session_id = obj.id
            added_sessions.append(obj)

    async def execute_side_effect(*_args, **_kwargs):
        execute_calls["n"] += 1
        result = MagicMock()
        mode = execute_mode["value"]
        if mode == "foreign_program":
            result.scalar_one_or_none.return_value = foreign_program
        elif mode == "missing_program":
            result.scalar_one_or_none.return_value = None
        else:
            # Odd calls: load program; even calls: reload persisted session
            if execute_calls["n"] % 2 == 1:
                result.scalar_one_or_none.return_value = owned_program
            else:
                result.scalar_one.return_value = added_sessions[-1]
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
    test_app.state.added_sessions = added_sessions  # type: ignore[attr-defined]
    test_app.state.owned_program = owned_program  # type: ignore[attr-defined]
    test_app.state.foreign_program = foreign_program  # type: ignore[attr-defined]
    test_app.state.execute_mode = execute_mode  # type: ignore[attr-defined]
    return test_app


@pytest.fixture
async def sessions_client(sessions_app: FastAPI):
    transport = ASGITransport(app=sessions_app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def unauthenticated_sessions_app() -> FastAPI:
    test_app = FastAPI()
    test_app.include_router(sessions.router, prefix="/api")
    return test_app


@pytest.fixture
async def unauthenticated_sessions_client(unauthenticated_sessions_app: FastAPI):
    transport = ASGITransport(app=unauthenticated_sessions_app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as ac:
        yield ac


def _payload(program_id: uuid.UUID, *, extra_exercise: bool = False) -> dict:
    start = datetime(2026, 7, 23, 18, 0, 0)
    exercises = [
        {
            "exercise_name": "Goblet Squat",
            "sets_completed": 3,
            "reps_completed": "10",
            "weight_kg": 20,
            "difficulty": 3,
            "skipped": False,
        },
        {
            "exercise_name": "Push-Up",
            "sets_completed": 3,
            "reps_completed": "12",
            "difficulty": 2,
            "skipped": False,
        },
    ]
    if extra_exercise:
        exercises.append(
            {
                "exercise_name": "Not In Program",
                "sets_completed": 1,
                "reps_completed": "5",
            }
        )
    return {
        "program_id": str(program_id),
        "start_time": start.isoformat(),
        "end_time": (start + timedelta(minutes=65)).isoformat(),
        "overall_feeling": 4,
        "fatigue_level": 3,
        "comments": "Solid session",
        "exercises": exercises,
    }


@pytest.mark.asyncio
async def test_create_session_success(
    sessions_client, sessions_app, current_user
):
    with patch(
        "app.ai.history.index_session_history",
        new_callable=AsyncMock,
    ) as mock_index:
        response = await sessions_client.post(
            "/api/sessions",
            json=_payload(sessions_app.state.owned_program.id),
        )

    assert response.status_code == 201
    data = response.json()
    assert data["user_id"] == str(current_user.id)
    assert data["program_id"] == str(sessions_app.state.owned_program.id)
    assert data["duration_minutes"] == 65
    assert len(data["exercises"]) == 2
    mock_index.assert_awaited_once()
    assert mock_index.await_args.kwargs["user_id"] == current_user.id


@pytest.mark.asyncio
async def test_create_session_multiple_exercises(sessions_client, sessions_app):
    with patch(
        "app.ai.history.index_session_history",
        new_callable=AsyncMock,
    ):
        response = await sessions_client.post(
            "/api/sessions",
            json=_payload(sessions_app.state.owned_program.id),
        )

    assert response.status_code == 201
    names = [ex["exercise_name"] for ex in response.json()["exercises"]]
    assert names == ["Goblet Squat", "Push-Up"]
    assert len(sessions_app.state.added_sessions[0].exercises) == 2


@pytest.mark.asyncio
async def test_create_session_unauthenticated(unauthenticated_sessions_client):
    response = await unauthenticated_sessions_client.post(
        "/api/sessions",
        json=_payload(uuid.uuid4()),
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_create_session_program_owned_by_another_user(
    sessions_client, sessions_app
):
    sessions_app.state.execute_mode["value"] = "foreign_program"
    with patch(
        "app.ai.history.index_session_history",
        new_callable=AsyncMock,
    ) as mock_index:
        response = await sessions_client.post(
            "/api/sessions",
            json=_payload(sessions_app.state.foreign_program.id),
        )

    assert response.status_code == 403
    assert response.json()["detail"] == "Program does not belong to this user"
    mock_index.assert_not_awaited()
    sessions_app.state.mock_db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_create_session_exercise_not_in_program(
    sessions_client, sessions_app
):
    with patch(
        "app.ai.history.index_session_history",
        new_callable=AsyncMock,
    ) as mock_index:
        response = await sessions_client.post(
            "/api/sessions",
            json=_payload(
                sessions_app.state.owned_program.id, extra_exercise=True
            ),
        )

    assert response.status_code == 400
    assert response.json()["detail"] == "Exercise does not belong to this program"
    mock_index.assert_not_awaited()
    sessions_app.state.mock_db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_create_session_invalid_program_id(sessions_client):
    response = await sessions_client.post(
        "/api/sessions",
        json={
            "program_id": "not-a-uuid",
            "start_time": datetime(2026, 7, 23, 18, 0, 0).isoformat(),
            "exercises": [],
        },
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_create_session_unknown_program(sessions_client, sessions_app):
    sessions_app.state.execute_mode["value"] = "missing_program"
    response = await sessions_client.post(
        "/api/sessions",
        json=_payload(uuid.uuid4()),
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "Program not found"


@pytest.mark.asyncio
async def test_create_session_transaction_rollback(
    sessions_client, sessions_app
):
    sessions_app.state.mock_db.commit.side_effect = Exception("db failure")
    with patch(
        "app.ai.history.index_session_history",
        new_callable=AsyncMock,
    ) as mock_index:
        response = await sessions_client.post(
            "/api/sessions",
            json=_payload(sessions_app.state.owned_program.id),
        )

    assert response.status_code == 500
    assert response.json()["detail"] == "Failed to create session"
    assert "db failure" not in response.text
    sessions_app.state.mock_db.rollback.assert_awaited()
    mock_index.assert_not_awaited()


@pytest.mark.asyncio
async def test_create_session_duplicate_submission_creates_two_rows(
    sessions_client, sessions_app, current_user
):
    with patch(
        "app.ai.history.index_session_history",
        new_callable=AsyncMock,
    ):
        first = await sessions_client.post(
            "/api/sessions",
            json=_payload(sessions_app.state.owned_program.id),
        )
        second = await sessions_client.post(
            "/api/sessions",
            json=_payload(sessions_app.state.owned_program.id),
        )

    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["id"] != second.json()["id"]
    assert len(sessions_app.state.added_sessions) == 2
    assert all(s.user_id == current_user.id for s in sessions_app.state.added_sessions)


@pytest.mark.asyncio
async def test_create_session_indexing_failure_still_returns_saved_session(
    sessions_client, sessions_app, current_user
):
    with patch(
        "app.ai.history.index_session_history",
        new_callable=AsyncMock,
        side_effect=RuntimeError("Groq down"),
    ):
        response = await sessions_client.post(
            "/api/sessions",
            json=_payload(sessions_app.state.owned_program.id),
        )

    assert response.status_code == 201
    assert response.json()["user_id"] == str(current_user.id)
    assert len(sessions_app.state.added_sessions) == 1
    # High-severity fix: failed AI commit must rollback the shared request session.
    sessions_app.state.mock_db.rollback.assert_awaited()

import uuid
from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.ai.schemas import (
    AfterExerciseResult,
    CoachPrompt,
    EndSessionResult,
    MidSessionResult,
    SessionExerciseSnapshot,
    SessionSnapshot,
    StartSessionResult,
)
from app.core.deps import get_current_user
from app.db import get_db
from app.models.program import Program, ProgramExercise
from app.models.user import User
from app.routers import coach


@pytest.fixture
def sample_program(current_user: User) -> Program:
    program_id = uuid.uuid4()
    program = Program(
        id=program_id,
        user_id=current_user.id,
        name="Strength Session",
        goal="strength",
        start_date=date(2026, 7, 23),
        end_date=date(2026, 7, 30),
        status="active",
        exercises=[
            ProgramExercise(
                id=uuid.uuid4(),
                program_id=program_id,
                exercise_name="Goblet Squat",
                sets=3,
                reps="8-10",
                rest_seconds=90,
                duration_minutes=None,
                notes="Brace core",
                order=0,
            )
        ],
    )
    return program


@pytest.fixture
def coach_app(current_user: User, sample_program: Program):
    test_app = FastAPI()
    test_app.include_router(coach.router, prefix="/api")

    mock_db = AsyncMock()

    async def default_execute(*_args, **_kwargs):
        result = MagicMock()
        result.scalar_one.return_value = current_user
        result.scalar_one_or_none.return_value = current_user
        return result

    mock_db.execute = AsyncMock(side_effect=default_execute)
    mock_db.commit = AsyncMock()
    mock_db.rollback = AsyncMock()

    async def override_get_db():
        yield mock_db

    async def override_get_current_user():
        return current_user

    test_app.dependency_overrides[get_db] = override_get_db
    test_app.dependency_overrides[get_current_user] = override_get_current_user
    test_app.state.mock_db = mock_db  # type: ignore[attr-defined]
    test_app.state.sample_program = sample_program  # type: ignore[attr-defined]
    test_app.state.current_user = current_user  # type: ignore[attr-defined]
    return test_app


def _wire_user_then_program(coach_app: FastAPI, program: Program | None):
    """Configure mock_db.execute: 1st call → user, later calls → program."""

    current_user = coach_app.state.current_user
    calls = {"n": 0}

    async def execute_side_effect(*_args, **_kwargs):
        calls["n"] += 1
        result = MagicMock()
        if calls["n"] == 1:
            result.scalar_one.return_value = current_user
            result.scalar_one_or_none.return_value = current_user
        else:
            result.scalar_one_or_none.return_value = program
            if program is not None:
                result.scalar_one.return_value = program
        return result

    coach_app.state.mock_db.execute = AsyncMock(side_effect=execute_side_effect)


@pytest.fixture
async def coach_client(coach_app: FastAPI):
    transport = ASGITransport(app=coach_app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def unauthenticated_coach_app() -> FastAPI:
    test_app = FastAPI()
    test_app.include_router(coach.router, prefix="/api")
    return test_app


@pytest.fixture
async def unauthenticated_coach_client(unauthenticated_coach_app: FastAPI):
    transport = ASGITransport(app=unauthenticated_coach_app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.asyncio
async def test_coach_start_success(coach_client, coach_app):
    expected = StartSessionResult(
        message="Let's warm up.",
        prompts=[
            CoachPrompt(
                id="readiness",
                label="How ready?",
                input_type="scale",
                scale_min=1,
                scale_max=5,
            )
        ],
    )
    with patch(
        "app.ai.live_coach.start_session_check_in",
        new_callable=AsyncMock,
        return_value=expected,
    ) as mock_start:
        response = await coach_client.post("/api/coach/start", json={})

    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "Let's warm up."
    assert len(data["prompts"]) == 1
    assert data["prompts"][0]["id"] == "readiness"
    mock_start.assert_awaited_once()


@pytest.mark.asyncio
async def test_coach_start_with_program_id(coach_client, coach_app, sample_program):
    _wire_user_then_program(coach_app, sample_program)
    expected = StartSessionResult(message="Ready for Strength Session.", prompts=[])

    with patch(
        "app.ai.live_coach.start_session_check_in",
        new_callable=AsyncMock,
        return_value=expected,
    ) as mock_start:
        response = await coach_client.post(
            "/api/coach/start",
            json={"program_id": str(sample_program.id)},
        )

    assert response.status_code == 200
    mock_start.assert_awaited_once()
    kwargs = mock_start.await_args.kwargs
    assert kwargs["program_name"] == "Strength Session"
    assert kwargs["upcoming_exercises"] is not None
    assert kwargs["upcoming_exercises"][0].exercise_name == "Goblet Squat"


@pytest.mark.asyncio
async def test_coach_start_program_not_found(coach_client, coach_app):
    _wire_user_then_program(coach_app, None)

    with patch(
        "app.ai.live_coach.start_session_check_in",
        new_callable=AsyncMock,
    ) as mock_start:
        response = await coach_client.post(
            "/api/coach/start",
            json={"program_id": str(uuid.uuid4())},
        )

    assert response.status_code == 404
    assert response.json()["detail"] == "Program not found"
    mock_start.assert_not_awaited()


@pytest.mark.asyncio
async def test_coach_start_program_forbidden(
    coach_client, coach_app, sample_program, current_user
):
    sample_program.user_id = uuid.uuid4()  # other owner
    _wire_user_then_program(coach_app, sample_program)

    with patch(
        "app.ai.live_coach.start_session_check_in",
        new_callable=AsyncMock,
    ) as mock_start:
        response = await coach_client.post(
            "/api/coach/start",
            json={"program_id": str(sample_program.id)},
        )

    assert response.status_code == 403
    mock_start.assert_not_awaited()
    assert current_user.id != sample_program.user_id


@pytest.mark.asyncio
async def test_coach_start_unauthenticated(unauthenticated_coach_client):
    response = await unauthenticated_coach_client.post("/api/coach/start", json={})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_coach_start_incomplete_profile(coach_client, current_user):
    current_user.profile.fitness_level = None

    with patch(
        "app.ai.live_coach.start_session_check_in",
        new_callable=AsyncMock,
    ) as mock_start:
        response = await coach_client.post("/api/coach/start", json={})

    assert response.status_code == 400
    assert response.json()["detail"] == "Incomplete profile"
    mock_start.assert_not_awaited()


@pytest.mark.asyncio
async def test_coach_start_ai_failure(coach_client):
    with patch(
        "app.ai.live_coach.start_session_check_in",
        new_callable=AsyncMock,
        side_effect=RuntimeError("groq down"),
    ):
        response = await coach_client.post("/api/coach/start", json={})

    assert response.status_code == 502
    assert response.json()["detail"] == "Coach start failed"
    assert "groq" not in response.text


@pytest.mark.asyncio
async def test_coach_after_exercise_success(coach_client):
    expected = AfterExerciseResult(
        message="Nice depth on that squat.",
        feedback=SessionExerciseSnapshot(
            exercise_name="Goblet Squat",
            sets_completed=3,
            reps_completed="10",
            weight_kg=20,
            difficulty=3,
            skipped=False,
            notes=None,
        ),
        safety_flag=False,
        prompts=[],
    )
    with patch(
        "app.ai.live_coach.after_exercise_feedback",
        new_callable=AsyncMock,
        return_value=expected,
    ) as mock_after:
        response = await coach_client.post(
            "/api/coach/after-exercise",
            json={
                "exercise_name": "Goblet Squat",
                "sets_completed": 3,
                "reps_completed": "10",
                "weight_kg": 20,
                "difficulty": 3,
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "Nice depth on that squat."
    assert data["feedback"]["exercise_name"] == "Goblet Squat"
    assert data["safety_flag"] is False
    mock_after.assert_awaited_once()


@pytest.mark.asyncio
async def test_coach_after_exercise_ai_failure(coach_client):
    with patch(
        "app.ai.live_coach.after_exercise_feedback",
        new_callable=AsyncMock,
        side_effect=RuntimeError("bad"),
    ):
        response = await coach_client.post(
            "/api/coach/after-exercise",
            json={"exercise_name": "Goblet Squat", "sets_completed": 3},
        )

    assert response.status_code == 502
    assert response.json()["detail"] == "After-exercise coach failed"


@pytest.mark.asyncio
async def test_coach_mid_session_success(coach_client):
    expected = MidSessionResult(
        message="Take 60 seconds, then continue.",
        safety_flag=False,
        suggested_action="rest",
        prompts=[],
    )
    with patch(
        "app.ai.live_coach.mid_session_coach",
        new_callable=AsyncMock,
        return_value=expected,
    ) as mock_mid:
        response = await coach_client.post(
            "/api/coach/mid-session",
            json={"user_message": "Should I rest?"},
        )

    assert response.status_code == 200
    data = response.json()
    assert data["suggested_action"] == "rest"
    assert data["message"] == "Take 60 seconds, then continue."
    mock_mid.assert_awaited_once()


@pytest.mark.asyncio
async def test_coach_mid_session_ai_failure(coach_client):
    with patch(
        "app.ai.live_coach.mid_session_coach",
        new_callable=AsyncMock,
        side_effect=RuntimeError("bad"),
    ):
        response = await coach_client.post(
            "/api/coach/mid-session",
            json={"user_message": "help"},
        )

    assert response.status_code == 502
    assert response.json()["detail"] == "Mid-session coach failed"


@pytest.mark.asyncio
async def test_coach_end_success(coach_client, coach_app):
    snapshot = SessionSnapshot(
        overall_feeling=4,
        fatigue_level=3,
        comments="Solid",
        duration_minutes=45,
        exercises=[
            SessionExerciseSnapshot(
                exercise_name="Goblet Squat",
                sets_completed=3,
                reps_completed="10",
                difficulty=3,
            )
        ],
    )
    expected = EndSessionResult(message="Great session — recover well.", snapshot=snapshot)

    with patch(
        "app.ai.live_coach.end_session_coach",
        new_callable=AsyncMock,
        return_value=expected,
    ) as mock_end:
        response = await coach_client.post(
            "/api/coach/end",
            json={
                "overall_feeling": 4,
                "fatigue_level": 3,
                "comments": "Solid",
                "duration_minutes": 45,
                "exercises": [
                    {
                        "exercise_name": "Goblet Squat",
                        "sets_completed": 3,
                        "reps_completed": "10",
                        "difficulty": 3,
                    }
                ],
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "Great session — recover well."
    assert data["snapshot"]["overall_feeling"] == 4
    assert len(data["snapshot"]["exercises"]) == 1
    mock_end.assert_awaited_once()
    # Coach end must not persist
    coach_app.state.mock_db.commit.assert_not_awaited()

@pytest.mark.asyncio
async def test_coach_end_ai_failure(coach_client):
    with patch(
        "app.ai.live_coach.end_session_coach",
        new_callable=AsyncMock,
        side_effect=RuntimeError("bad"),
    ):
        response = await coach_client.post(
            "/api/coach/end",
            json={"overall_feeling": 4, "exercises": []},
        )

    assert response.status_code == 502
    assert response.json()["detail"] == "End-session coach failed"

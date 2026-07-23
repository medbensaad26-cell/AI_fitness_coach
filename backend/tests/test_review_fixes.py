"""Regression tests for critical/high review fixes."""

import importlib

import pytest


def _restore_test_config(monkeypatch):
    monkeypatch.setenv("SECRET_KEY", "test-secret-key-not-for-production")
    monkeypatch.setenv(
        "DATABASE_URL",
        "postgresql+asyncpg://fitness:test@localhost:5432/fitness_coach",
    )
    import app.core.config as config_module

    importlib.reload(config_module)


def test_config_requires_secret_key(monkeypatch):
    monkeypatch.setenv(
        "DATABASE_URL",
        "postgresql+asyncpg://fitness:test@localhost:5432/fitness_coach",
    )
    monkeypatch.setenv("SECRET_KEY", "")

    with pytest.raises(RuntimeError, match="SECRET_KEY"):
        import app.core.config as config_module

        importlib.reload(config_module)

    _restore_test_config(monkeypatch)


def test_config_requires_database_url(monkeypatch):
    monkeypatch.setenv("SECRET_KEY", "test-secret-key-not-for-production")
    monkeypatch.setenv("DATABASE_URL", "")

    with pytest.raises(RuntimeError, match="DATABASE_URL"):
        import app.core.config as config_module

        importlib.reload(config_module)

    _restore_test_config(monkeypatch)


def test_config_accepts_required_env_without_hardcoded_db_password(monkeypatch):
    monkeypatch.setenv("SECRET_KEY", "test-secret-key-not-for-production")
    monkeypatch.setenv(
        "DATABASE_URL",
        "postgresql+asyncpg://fitness:test@localhost:5432/fitness_coach",
    )
    import app.core.config as config_module

    mod = importlib.reload(config_module)
    assert mod.SECRET_KEY == "test-secret-key-not-for-production"
    assert mod.DATABASE_URL.startswith("postgresql+asyncpg://")
    # No hardcoded legacy default password embedded in source defaults
    assert "fitness:fitness@" not in mod.DATABASE_URL


@pytest.mark.asyncio
async def test_patch_profile_commit_failure_rolls_back(client, app):
    app.state.mock_db.commit.side_effect = Exception("db failure")

    response = await client.patch(
        "/api/me/profile",
        json={"available_time_minutes": 40},
    )

    assert response.status_code == 500
    assert response.json()["detail"] == "Failed to update profile"
    assert "db failure" not in response.text
    app.state.mock_db.rollback.assert_awaited()

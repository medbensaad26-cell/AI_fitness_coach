import pytest


@pytest.mark.asyncio
async def test_patch_profile_success(client, current_user):
    response = await client.patch(
        "/api/me/profile",
        json={"available_time_minutes": 45},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["available_time_minutes"] == 45
    assert data["email"] == "alex@example.com"
    assert data["id"] == str(current_user.id)
    assert current_user.profile.available_time_minutes == 45


@pytest.mark.asyncio
async def test_patch_profile_partial_update_leaves_omitted_fields(
    client, current_user
):
    original_name = current_user.profile.name
    original_goal = current_user.profile.primary_goal
    original_equipment = current_user.profile.available_equipment

    response = await client.patch(
        "/api/me/profile",
        json={"available_time_minutes": 30},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["available_time_minutes"] == 30
    assert data["name"] == original_name
    assert data["primary_goal"] == original_goal
    assert data["available_equipment"] == original_equipment
    assert current_user.profile.name == original_name
    assert current_user.profile.primary_goal == original_goal
    assert current_user.profile.available_equipment == original_equipment


@pytest.mark.asyncio
async def test_patch_profile_unauthenticated(unauthenticated_client):
    response = await unauthenticated_client.patch(
        "/api/me/profile",
        json={"available_time_minutes": 45},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
@pytest.mark.parametrize("invalid_value", [0, -1, -10])
async def test_patch_profile_invalid_available_time_minutes(
    client, current_user, invalid_value
):
    before = current_user.profile.available_time_minutes

    response = await client.patch(
        "/api/me/profile",
        json={"available_time_minutes": invalid_value},
    )

    assert response.status_code == 422
    assert current_user.profile.available_time_minutes == before


@pytest.mark.asyncio
async def test_patch_profile_existing_fields_unchanged_when_omitted(
    client, current_user
):
    current_user.profile.available_time_minutes = 60
    current_user.profile.fitness_level = "advanced"

    response = await client.patch(
        "/api/me/profile",
        json={"name": "Sam"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Sam"
    assert data["available_time_minutes"] == 60
    assert data["fitness_level"] == "advanced"
    assert current_user.profile.available_time_minutes == 60
    assert current_user.profile.fitness_level == "advanced"

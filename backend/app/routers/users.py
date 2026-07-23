from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.db import get_db
from app.models.user import User, UserProfile
from app.schemas.user import UserProfileResponse, UserProfileUpdate

router = APIRouter(tags=["users"])


def _profile_response(user: User, profile: UserProfile) -> UserProfileResponse:
    return UserProfileResponse(
        id=user.id,
        email=user.email,
        name=profile.name,
        age=profile.age,
        sex=profile.sex,
        height_cm=profile.height_cm,
        weight_kg=profile.weight_kg,
        fitness_level=profile.fitness_level,
        primary_goal=profile.primary_goal,
        training_frequency=profile.training_frequency,
        available_equipment=profile.available_equipment,
        limitations=profile.limitations,
        available_time_minutes=profile.available_time_minutes,
        created_at=profile.created_at,
        updated_at=profile.updated_at,
    )


async def _load_user_with_profile(
    db: AsyncSession,
    user_id,
) -> User:
    result = await db.execute(
        select(User)
        .options(selectinload(User.profile))
        .where(User.id == user_id)
    )
    return result.scalar_one()


@router.get(
    "/me/profile",
    response_model=UserProfileResponse,
    summary="Get my profile",
    description="Return the authenticated user's fitness profile, including available_time_minutes.",
)
async def get_my_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await _load_user_with_profile(db, current_user.id)
    if user.profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )
    return _profile_response(user, user.profile)


@router.patch(
    "/me/profile",
    response_model=UserProfileResponse,
    status_code=status.HTTP_200_OK,
    summary="Update my profile",
    description=(
        "Partial update of the authenticated user's profile. "
        "Omitted fields remain unchanged. Does not accept user_id from the body."
    ),
)
async def update_my_profile(
    payload: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        user = await _load_user_with_profile(db, current_user.id)
        if user.profile is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profile not found",
            )

        updates = payload.model_dump(exclude_unset=True)
        for field, value in updates.items():
            setattr(user.profile, field, value)
        user.profile.updated_at = date.today()

        await db.commit()

        user = await _load_user_with_profile(db, current_user.id)
        return _profile_response(user, user.profile)
    except HTTPException:
        await db.rollback()
        raise
    except Exception:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update profile",
        ) from None

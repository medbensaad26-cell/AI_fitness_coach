from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.db import get_db
from app.models.user import User
from app.schemas.user import UserProfileResponse

router = APIRouter(tags=["users"])


@router.get("/me/profile", response_model=UserProfileResponse)
async def get_my_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User)
        .options(selectinload(User.profile))
        .where(User.id == current_user.id)
    )
    user = result.scalar_one()
    if user.profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )

    profile = user.profile
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
        created_at=profile.created_at,
        updated_at=profile.updated_at,
    )

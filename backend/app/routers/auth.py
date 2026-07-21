from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password, verify_password
from app.db import get_db
from app.models.user import User, UserProfile
from app.schemas.auth import LoginRequest, TokenResponse
from app.schemas.user import UserCreate

router = APIRouter(tags=["auth"])


@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(payload: UserCreate, db: AsyncSession = Depends(get_db)):
    try:
        existing = await db.execute(select(User).where(User.email == payload.email))
        if existing.scalar_one_or_none() is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered",
            )

        user = User(
            email=payload.email,
            hashed_password=hash_password(payload.password),
        )
        db.add(user)
        await db.flush()

        today = date.today()
        profile = UserProfile(
            user_id=user.id,
            name=payload.name,
            age=payload.age,
            sex=payload.sex,
            height_cm=payload.height_cm,
            weight_kg=payload.weight_kg,
            fitness_level=payload.fitness_level,
            primary_goal=payload.primary_goal,
            training_frequency=payload.training_frequency,
            available_equipment=payload.available_equipment,
            limitations=payload.limitations,
            created_at=today,
            updated_at=today,
        )
        db.add(profile)
        await db.commit()

        return {"message": "User registered successfully"}
    except HTTPException:
        await db.rollback()
        raise
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    except Exception as exc:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed",
        ) from exc


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    token = create_access_token(user.id)
    return TokenResponse(access_token=token)

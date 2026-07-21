import os


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://fitness:fitness123@localhost:5432/fitness_coach",
)
SYNC_DATABASE_URL = DATABASE_URL.replace("+asyncpg", "")

SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))

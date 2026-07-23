"""Application settings loaded from environment variables / `.env`.

Secrets (SECRET_KEY, GROQ_API_KEY, database password inside DATABASE_URL) must come
from the environment. Do not commit real values. See `.env.example`.

Note: OPENAI_API_KEY is not used — chat goes through GROQ_API_KEY + GROQ_BASE_URL.
"""

import os

from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
SECRET_KEY = os.getenv("SECRET_KEY", "").strip()

if not DATABASE_URL:
    raise RuntimeError(
        "DATABASE_URL environment variable is required. "
        "Copy .env.example to .env and set it (Compose overrides the host to `db`)."
    )
if not SECRET_KEY:
    raise RuntimeError(
        "SECRET_KEY environment variable is required. "
        "Copy .env.example to .env and set a strong secret."
    )

SYNC_DATABASE_URL = DATABASE_URL.replace("+asyncpg", "")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))

# --- AI / RAG (Person A) — Groq (OpenAI-compatible API); not OPENAI_API_KEY ---

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_BASE_URL = os.getenv("GROQ_BASE_URL", "https://api.groq.com/openai/v1")
CHAT_MODEL = os.getenv("CHAT_MODEL", "llama-3.3-70b-versatile")

# Embeddings: in-process via fastembed inside the API container (free, no extra service)
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "BAAI/bge-small-en-v1.5")
EMBEDDING_DIMENSIONS = int(os.getenv("EMBEDDING_DIMENSIONS", "384"))

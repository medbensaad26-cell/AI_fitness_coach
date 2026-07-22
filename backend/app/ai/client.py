"""LLM client for chat (Groq). Embeddings are handled in embeddings.py via fastembed."""

from functools import lru_cache

from openai import AsyncOpenAI

from app.core.config import GROQ_API_KEY, GROQ_BASE_URL


@lru_cache
def get_chat_client() -> AsyncOpenAI:
    """Async client pointed at Groq for program generation and live coaching."""
    if not GROQ_API_KEY:
        raise RuntimeError(
            "GROQ_API_KEY is not set. Add it to your environment or .env file."
        )
    return AsyncOpenAI(api_key=GROQ_API_KEY, base_url=GROQ_BASE_URL)

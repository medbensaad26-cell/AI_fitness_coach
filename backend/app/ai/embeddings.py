"""Turn text into embedding vectors with fastembed (runs inside the API container).

Why fastembed (not Ollama/OpenAI): free, no extra Docker service, and the Ollama
image pull was too heavy for our setup. Same RAG contract: text -> float vector.
"""

from __future__ import annotations

import asyncio
from functools import lru_cache

from fastembed import TextEmbedding

from app.core.config import EMBEDDING_MODEL


@lru_cache
def _get_embedding_model() -> TextEmbedding:
    """Load once per process; first call may download model weights into cache."""
    return TextEmbedding(model_name=EMBEDDING_MODEL)


def _embed_sync(texts: list[str]) -> list[list[float]]:
    model = _get_embedding_model()
    # fastembed yields numpy arrays / lists — normalize to plain Python floats
    return [list(map(float, vector)) for vector in model.embed(texts)]


async def embed_texts(texts: list[str]) -> list[list[float]]:
    """Embed one or more strings (runs sync model in a worker thread)."""
    if not texts:
        return []
    return await asyncio.to_thread(_embed_sync, texts)


async def embed_text(text: str) -> list[float]:
    """Convenience wrapper for a single string."""
    vectors = await embed_texts([text])
    return vectors[0]

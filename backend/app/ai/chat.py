"""Chat completions via Groq (llama-3.3-70b-versatile by default)."""

from openai.types.chat import ChatCompletionMessageParam

from app.ai.client import get_chat_client
from app.core.config import CHAT_MODEL


async def chat_completion(
    messages: list[ChatCompletionMessageParam],
    *,
    model: str | None = None,
    temperature: float = 0.4,
    max_tokens: int | None = 2048,
) -> str:
    """Send a chat request to Groq and return the assistant text.

    ``messages`` uses the usual roles: system / user / assistant.
    Temperature is moderately low so coaching output stays consistent.
    """
    client = get_chat_client()
    response = await client.chat.completions.create(
        model=model or CHAT_MODEL,
        messages=messages,
        temperature=temperature,
        max_tokens=max_tokens,
    )
    content = response.choices[0].message.content
    if not content:
        raise RuntimeError("Groq returned an empty chat completion.")
    return content

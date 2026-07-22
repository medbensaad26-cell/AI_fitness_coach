"""One-off Groq smoke test. Run from backend/: python ../scripts/smoke_groq.py"""
import asyncio
import sys
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")
sys.path.insert(0, str(ROOT / "backend"))

from app.ai.chat import chat_completion  # noqa: E402


async def main() -> None:
    text = await chat_completion(
        [{"role": "user", "content": "Reply with exactly: OK"}],
        max_tokens=16,
    )
    print("SUCCESS")
    print("REPLY:", repr(text))


if __name__ == "__main__":
    asyncio.run(main())

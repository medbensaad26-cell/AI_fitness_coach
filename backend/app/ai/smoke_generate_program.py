"""Smoke-test program generation inside Docker.

    docker compose exec api python -m app.ai.smoke_generate_program
"""

from __future__ import annotations

import asyncio
import json

from app.ai.generate_program import generate_program
from app.ai.schemas import ProfileContext
from app.db import async_session


async def _main() -> None:
    profile = ProfileContext(
        name="Alex",
        age=28,
        sex="female",
        height_cm=165,
        weight_kg=62,
        fitness_level="beginner",
        primary_goal="build strength",
        training_frequency="3 days/week",
        available_equipment="dumbbells, yoga mat",
        limitations="sensitive knees — avoid deep painful squats",
    )

    async with async_session() as db:
        program = await generate_program(db, profile)

    print("GENERATE_OK")
    print(json.dumps(program.model_dump(mode="json"), indent=2))


if __name__ == "__main__":
    asyncio.run(_main())

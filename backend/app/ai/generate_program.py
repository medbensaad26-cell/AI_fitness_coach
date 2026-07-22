"""Generate a structured workout program from profile + RAG + exercise catalog.

Person B calls ``generate_program`` from a route; Person A owns the AI logic.
"""

from __future__ import annotations

import json
import re
import uuid
from datetime import date, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.catalog import (
    format_catalog_block,
    resolve_exercise_name,
    select_catalog_exercises,
)
from app.ai.chat import chat_completion
from app.ai.history import retrieve_user_history
from app.ai.retrieval import retrieve_knowledge
from app.ai.schemas import GeneratedProgram, GeneratedProgramExercise, ProfileContext
from app.models.exercise import Exercise
from app.schemas.program import ProgramCreate, ProgramExerciseCreate

_SYSTEM_PROMPT = """\
You are an expert fitness coach for an AI coaching app.
Return ONLY valid JSON (no markdown fences, no commentary) with this shape:
{
  "name": "string — short session/program title",
  "goal": "string — session focus aligned with the user goal",
  "exercises": [
    {
      "exercise_id": "catalog id when possible",
      "exercise_name": "exact catalog name when possible",
      "sets": 1,
      "reps": "string e.g. 8-10 or 30s",
      "rest_seconds": 90,
      "duration_minutes": null,
      "notes": "short coaching cue or null",
      "order": 0
    }
  ]
}

Rules:
- Prefer exercises from the provided CATALOG (use exercise_id + exact name).
- Only invent an exercise if the catalog cannot cover the need; then set exercise_id to null.
- Respect equipment, fitness level, and limitations strictly.
- Prefer safe, practical exercises; avoid anything contraindicated by limitations.
- Use retrieved knowledge when relevant (form, safety, programming).
- 4 to 8 exercises, ordered from warmup/compound to accessories.
- sets must be integers >= 1; order starts at 0 and increases by 1.
- rest_seconds is an integer or null; duration_minutes only for timed work else null.
"""


def _profile_block(profile: ProfileContext) -> str:
    return (
        f"Name: {profile.name or 'Athlete'}\n"
        f"Age: {profile.age}\n"
        f"Sex: {profile.sex}\n"
        f"Height_cm: {profile.height_cm}\n"
        f"Weight_kg: {profile.weight_kg}\n"
        f"Fitness level: {profile.fitness_level}\n"
        f"Primary goal: {profile.primary_goal}\n"
        f"Training frequency: {profile.training_frequency}\n"
        f"Available equipment: {profile.available_equipment or 'bodyweight'}\n"
        f"Limitations: {profile.limitations or 'none'}\n"
    )


def _knowledge_block(chunks: list) -> str:
    if not chunks:
        return "(no retrieved knowledge)"
    lines = []
    for i, chunk in enumerate(chunks, start=1):
        topic = chunk.topic or "general"
        lines.append(f"{i}. [{chunk.category}/{topic}] {chunk.content}")
    return "\n".join(lines)


def _retrieval_query(profile: ProfileContext) -> str:
    parts = [
        profile.primary_goal or "general fitness",
        profile.fitness_level or "beginner",
        profile.available_equipment or "bodyweight",
        profile.limitations or "",
        "workout program exercise selection safety",
    ]
    return " ".join(p for p in parts if p).strip()


def _extract_json(text: str) -> dict:
    """Parse model JSON, tolerating accidental markdown fences."""
    cleaned = text.strip()
    fence = re.search(r"```(?:json)?\s*([\s\S]*?)```", cleaned)
    if fence:
        cleaned = fence.group(1).strip()
    return json.loads(cleaned)


def _canonicalize_exercises(
    generated: GeneratedProgram,
    catalog: list[Exercise],
) -> GeneratedProgram:
    fixed: list[GeneratedProgramExercise] = []
    for ex in generated.exercises:
        resolved_id, resolved_name = resolve_exercise_name(
            exercise_id=ex.exercise_id,
            exercise_name=ex.exercise_name,
            catalog=catalog,
        )
        fixed.append(
            ex.model_copy(
                update={"exercise_id": resolved_id, "exercise_name": resolved_name}
            )
        )
    return generated.model_copy(update={"exercises": fixed})


def _to_program_create(
    generated: GeneratedProgram,
    *,
    start_date: date,
) -> ProgramCreate:
    exercises = [
        ProgramExerciseCreate(
            exercise_name=ex.exercise_name,
            sets=ex.sets,
            reps=ex.reps,
            rest_seconds=ex.rest_seconds,
            duration_minutes=ex.duration_minutes,
            notes=(
                f"[id:{ex.exercise_id}] {ex.notes}".strip()
                if ex.exercise_id and ex.notes
                else (f"[id:{ex.exercise_id}]" if ex.exercise_id else ex.notes)
            ),
            order=ex.order,
        )
        for ex in sorted(generated.exercises, key=lambda e: e.order)
    ]
    for index, exercise in enumerate(exercises):
        exercise.order = index

    return ProgramCreate(
        name=generated.name,
        goal=generated.goal,
        start_date=start_date,
        end_date=start_date + timedelta(days=7),
        status="active",
        exercises=exercises,
    )


async def generate_program(
    db: AsyncSession,
    profile: ProfileContext,
    *,
    user_id: uuid.UUID | None = None,
    start_date: date | None = None,
    knowledge_limit: int = 5,
    history_limit: int = 3,
) -> ProgramCreate:
    """Build a ProgramCreate payload from profile + retrieved knowledge + catalog.

    What: one personalized workout program ready for B to POST/save.
    Why: turns Groq + RAG into the existing program schema (no free-form chat).
    How: catalog candidates + tips (+ optional history) -> Groq JSON -> validate.
    """
    query = _retrieval_query(profile)
    chunks = await retrieve_knowledge(db, query, limit=knowledge_limit)
    catalog = await select_catalog_exercises(db, profile)

    history_block = "(no personal history yet)"
    if user_id is not None:
        memories = await retrieve_user_history(
            db, user_id, query, limit=history_limit
        )
        if memories:
            history_block = "\n\n".join(
                f"- feeling={m.overall_feeling} fatigue={m.fatigue_level}\n{m.summary}"
                for m in memories
            )

    user_prompt = (
        "Create one workout session for this athlete.\n\n"
        f"PROFILE\n{_profile_block(profile)}\n"
        f"CATALOG (prefer these)\n{format_catalog_block(catalog)}\n"
        f"RETRIEVED KNOWLEDGE\n{_knowledge_block(chunks)}\n"
        f"PERSONAL SESSION HISTORY\n{history_block}\n"
        "Adapt load/exercise choices using history when present "
        "(e.g. high fatigue → easier volume; skipped moves → alternatives).\n"
    )

    raw = await chat_completion(
        [
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.3,
        max_tokens=1800,
    )

    try:
        payload = _extract_json(raw)
        generated = GeneratedProgram.model_validate(payload)
        generated = _canonicalize_exercises(generated, catalog)
    except (json.JSONDecodeError, ValueError) as exc:
        raise RuntimeError(
            f"Model returned invalid program JSON: {exc}\nRaw:\n{raw[:800]}"
        ) from exc

    return _to_program_create(
        generated,
        start_date=start_date or date.today(),
    )

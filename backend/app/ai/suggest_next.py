"""Suggest the next workout from profile + knowledge + personal history.

Person B calls ``suggest_next_program`` when the app needs continuity
("what should I do next?") after sessions have been indexed.
"""

from __future__ import annotations

import json
import uuid
from datetime import date
from dataclasses import dataclass

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.catalog import (
    format_catalog_block,
    select_catalog_exercises,
)
from app.ai.chat import chat_completion
from app.ai.generate_program import (
    _canonicalize_exercises,
    _extract_json,
    _knowledge_block,
    _profile_block,
    _retrieval_query,
    _to_program_create,
)
from app.ai.history import get_recent_user_history, retrieve_user_history
from app.ai.retrieval import retrieve_knowledge
from app.ai.schemas import GeneratedProgram, ProfileContext
from app.schemas.program import ProgramCreate

_SYSTEM_PROMPT = """\
You are an expert fitness coach planning the NEXT session after recent workouts.
Return ONLY valid JSON (no markdown fences) with this shape:
{
  "name": "string",
  "goal": "string",
  "exercises": [
    {
      "exercise_id": "catalog id when possible",
      "exercise_name": "exact catalog name when possible",
      "sets": 1,
      "reps": "string",
      "rest_seconds": 90,
      "duration_minutes": null,
      "notes": "string or null",
      "order": 0
    }
  ],
  "rationale": "2-4 sentences explaining why this is the logical next session",
  "adaptations": [
    "short bullet of a concrete change vs recent sessions"
  ]
}

Adaptation rules (apply when history supports them):
- High fatigue (4-5) or low feeling (1-2): reduce volume/intensity; favor recovery-friendly work.
- Repeatedly skipped exercises: replace with similar pattern the user tolerates.
- Pain / joint comments: treat as hard constraints; avoid aggravating patterns.
- If last session went well (feeling 4-5, fatigue <=3): progress slightly (reps/load/variation).
- Prefer exercises from CATALOG (exercise_id + exact name).
- Prefer 4-8 exercises; respect equipment, level, and limitations.
- Prefer continuity ( complementary focus) over random unrelated workouts.
"""


@dataclass(frozen=True)
class SuggestNextOutput:
    """Service result B can persist + show in the UI."""

    program: ProgramCreate
    rationale: str
    adaptations: list[str]


def _history_block(chunks: list) -> str:
    if not chunks:
        return "(none)"
    parts = []
    for i, chunk in enumerate(chunks, start=1):
        parts.append(
            f"{i}. feeling={chunk.overall_feeling} fatigue={chunk.fatigue_level}\n"
            f"{chunk.summary}"
        )
    return "\n\n".join(parts)


async def suggest_next_program(
    db: AsyncSession,
    profile: ProfileContext,
    user_id: uuid.UUID,
    *,
    start_date: date | None = None,
    knowledge_limit: int = 5,
    recent_limit: int = 3,
    similar_limit: int = 3,
) -> SuggestNextOutput:
    """Propose the next ProgramCreate using continuity + adaptation.

    What: next logical workout after this user's history.
    Why: plain generate_program is first-session oriented; this is progressive coaching.
    How: recent + similar memories + knowledge RAG → Groq JSON → validate → ProgramCreate.
    """
    query = _retrieval_query(profile)
    # Also bias retrieval toward recovery/adaptation cues from profile limitations
    knowledge_query = f"{query} fatigue recovery progressive overload skipped exercises pain"
    chunks = await retrieve_knowledge(db, knowledge_query, limit=knowledge_limit)
    recent = await get_recent_user_history(db, user_id, limit=recent_limit)
    similar = await retrieve_user_history(db, user_id, knowledge_query, limit=similar_limit)
    catalog = await select_catalog_exercises(db, profile)

    user_prompt = (
        "Plan the NEXT workout session for this athlete.\n\n"
        f"PROFILE\n{_profile_block(profile)}\n"
        f"CATALOG (prefer these)\n{format_catalog_block(catalog)}\n"
        f"RETRIEVED KNOWLEDGE\n{_knowledge_block(chunks)}\n"
        f"RECENT SESSIONS (newest first)\n{_history_block(recent)}\n"
        f"SIMILAR PAST SESSIONS\n{_history_block(similar)}\n"
        "Follow the adaptation rules. If history is empty, create a sensible first session.\n"
    )

    raw = await chat_completion(
        [
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.25,
        max_tokens=2000,
    )

    try:
        payload = _extract_json(raw)
        rationale = str(payload.pop("rationale", "")).strip() or (
            "Next session chosen from profile and available history."
        )
        adaptations_raw = payload.pop("adaptations", [])
        if not isinstance(adaptations_raw, list):
            adaptations_raw = []
        adaptations = [str(item).strip() for item in adaptations_raw if str(item).strip()]
        generated = GeneratedProgram.model_validate(payload)
        generated = _canonicalize_exercises(generated, catalog)
    except (json.JSONDecodeError, ValueError) as exc:
        raise RuntimeError(
            f"Model returned invalid suggest-next JSON: {exc}\nRaw:\n{raw[:800]}"
        ) from exc

    program = _to_program_create(generated, start_date=start_date or date.today())
    return SuggestNextOutput(
        program=program,
        rationale=rationale,
        adaptations=adaptations,
    )

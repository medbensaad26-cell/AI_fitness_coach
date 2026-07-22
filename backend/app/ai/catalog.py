"""Select exercises from the DB catalog for program generation prompts."""

from __future__ import annotations

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.schemas import ProfileContext
from app.models.exercise import Exercise

_LEVEL_ORDER = {"beginner": 0, "intermediate": 1, "advanced": 2}


def _level_rank(value: str | None) -> int:
    if not value:
        return 1
    return _LEVEL_ORDER.get(value.lower(), 1)


def _equipment_tokens(profile: ProfileContext) -> set[str]:
    raw = (profile.available_equipment or "bodyweight").lower()
    # Normalize common synonyms so catalog filters work
    tokens = {t.strip() for t in raw.replace("/", ",").replace("|", ",").split(",") if t.strip()}
    aliases = {
        "dumbbells": "dumbbell",
        "dumbell": "dumbbell",
        "barbells": "barbell",
        "bands": "resistance_band",
        "resistance bands": "resistance_band",
        "pull up bar": "pull_up_bar",
        "pull-up bar": "pull_up_bar",
        "body weight": "bodyweight",
        "none": "bodyweight",
    }
    normalized: set[str] = set()
    for token in tokens:
        normalized.add(aliases.get(token, token.replace(" ", "_")))
    if not normalized:
        normalized.add("bodyweight")
    return normalized


async def select_catalog_exercises(
    db: AsyncSession,
    profile: ProfileContext,
    *,
    limit: int = 40,
) -> list[Exercise]:
    """Pick catalog rows that roughly match level + equipment.

    What: candidate list for Groq so it prefers real exercises.
    Why: reduce invented/unsafe movement names.
    How: filter by difficulty ceiling and equipment overlap; fall back to all.
    """
    level = _level_rank(profile.fitness_level)
    allowed_levels = [
        name for name, rank in _LEVEL_ORDER.items() if rank <= level
    ] or list(_LEVEL_ORDER)

    stmt = select(Exercise).where(
        or_(Exercise.difficulty.is_(None), Exercise.difficulty.in_(allowed_levels))
    )
    rows = list((await db.execute(stmt)).scalars().all())
    if not rows:
        return []

    equip = _equipment_tokens(profile)
    limitations = (profile.limitations or "").lower()

    scored: list[tuple[int, Exercise]] = []
    for ex in rows:
        ex_equip = {e.lower().replace(" ", "_") for e in (ex.equipment or [])}
        # Bodyweight always allowed; otherwise require overlap
        if ex_equip and ex_equip != {"bodyweight"} and not (ex_equip & equip) and "bodyweight" not in ex_equip:
            # still allow if profile has vague "gym" / "full gym"
            if not any(t in {"gym", "full_gym", "machines"} for t in equip):
                continue
        score = 0
        if ex_equip & equip:
            score += 2
        if "bodyweight" in ex_equip and "bodyweight" in equip:
            score += 1
        # Soft penalty when limitations mention knees/back and contraindications match
        contra = " ".join(ex.contraindications or []).lower()
        if "knee" in limitations and "knee" in contra:
            score -= 3
        if "back" in limitations and ("back" in contra or "disc" in contra):
            score -= 3
        scored.append((score, ex))

    scored.sort(key=lambda item: (-item[0], item[1].name))
    selected = [ex for score, ex in scored if score >= 0][:limit]
    if len(selected) < 8:
        # Fallback: top by name from unfiltered difficulty set
        selected = rows[:limit]
    return selected


def format_catalog_block(exercises: list[Exercise]) -> str:
    if not exercises:
        return "(catalog empty — use safe common exercises)"
    lines = []
    for ex in exercises:
        equip = ", ".join(ex.equipment) if ex.equipment else "n/a"
        lines.append(
            f"- id={ex.id} | name={ex.name} | pattern={ex.pattern} | "
            f"difficulty={ex.difficulty or 'n/a'} | equipment=[{equip}]"
        )
    return "\n".join(lines)


def resolve_exercise_name(
    *,
    exercise_id: str | None,
    exercise_name: str,
    catalog: list[Exercise],
) -> tuple[str | None, str]:
    """Map model output to a catalog id + canonical name when possible."""
    by_id = {ex.id: ex for ex in catalog}
    by_name = {ex.name.lower(): ex for ex in catalog}
    for ex in catalog:
        for alias in ex.aliases or []:
            by_name[alias.lower()] = ex

    if exercise_id and exercise_id in by_id:
        ex = by_id[exercise_id]
        return ex.id, ex.name

    match = by_name.get(exercise_name.lower().strip())
    if match:
        return match.id, match.name
    return exercise_id, exercise_name

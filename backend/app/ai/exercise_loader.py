"""Load exercise catalog JSON files from knowledge_docs/exercises."""

from __future__ import annotations

import json
from pathlib import Path

from pydantic import BaseModel, Field

EXERCISES_ROOT = Path(__file__).resolve().parent / "knowledge_docs" / "exercises"


class ExerciseRecord(BaseModel):
    id: str
    name: str
    aliases: list[str] = Field(default_factory=list)
    pattern: str
    type: str
    mechanics: str | None = None
    force: str | None = None
    primary_muscles: list[str] = Field(default_factory=list)
    secondary_muscles: list[str] = Field(default_factory=list)
    equipment: list[str] = Field(default_factory=list)
    difficulty: str | None = None
    instructions: str
    form_cues: list[str] = Field(default_factory=list)
    contraindications: list[str] = Field(default_factory=list)
    regressions: list[str] = Field(default_factory=list)
    progressions: list[str] = Field(default_factory=list)
    safety_notes: str | None = None
    common_mistakes: list[str] = Field(default_factory=list)
    source: str | None = None
    scientific_confidence: str | None = None


def load_exercise_records() -> list[ExerciseRecord]:
    """Parse all exercise JSON files; skip invalid files with a clear error list."""
    if not EXERCISES_ROOT.exists():
        return []

    records: list[ExerciseRecord] = []
    errors: list[str] = []
    for path in sorted(EXERCISES_ROOT.rglob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            records.append(ExerciseRecord.model_validate(data))
        except Exception as exc:  # noqa: BLE001 — collect and report after scan
            errors.append(f"{path.name}: {exc}")
    if errors:
        raise RuntimeError(
            "Failed to parse some exercise JSON files:\n" + "\n".join(errors)
        )
    return records


def exercise_to_rag_text(record: ExerciseRecord) -> str:
    """Compact coaching blurb for knowledge_chunks (optional RAG side of catalog)."""
    cues = "; ".join(record.form_cues[:4]) if record.form_cues else ""
    mistakes = "; ".join(record.common_mistakes[:3]) if record.common_mistakes else ""
    contra = ", ".join(record.contraindications) if record.contraindications else "none"
    parts = [
        f"Exercise: {record.name}",
        f"Pattern: {record.pattern}; difficulty: {record.difficulty or 'n/a'}",
        f"Equipment: {', '.join(record.equipment) or 'none'}",
        f"Primary muscles: {', '.join(record.primary_muscles)}",
        f"Instructions: {record.instructions}",
    ]
    if cues:
        parts.append(f"Form cues: {cues}")
    if record.safety_notes:
        parts.append(f"Safety: {record.safety_notes}")
    if mistakes:
        parts.append(f"Common mistakes: {mistakes}")
    parts.append(f"Contraindications: {contra}")
    return "\n".join(parts)

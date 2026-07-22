"""Live in-session coaching turns (text-first; voice can wrap the same payloads).

Person B exposes HTTP routes; Person C builds the workout UI / optional voice.
Person A owns these functions.
"""

from __future__ import annotations

import json
import re

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.chat import chat_completion
from app.ai.generate_program import _extract_json, _profile_block
from app.ai.retrieval import retrieve_knowledge
from app.ai.schemas import (
    AfterExerciseInput,
    AfterExerciseResult,
    CoachPrompt,
    EndSessionInput,
    EndSessionResult,
    MidSessionInput,
    MidSessionResult,
    PlannedExerciseContext,
    ProfileContext,
    SessionExerciseSnapshot,
    SessionSnapshot,
    StartSessionResult,
)

_START_PROMPTS = [
    CoachPrompt(
        id="readiness",
        label="How ready do you feel to train? (1 exhausted – 5 fully ready)",
        input_type="scale",
        scale_min=1,
        scale_max=5,
    ),
    CoachPrompt(
        id="pain_check",
        label="Any pain or unusual discomfort right now? (short note, or 'none')",
        input_type="text",
        required=False,
    ),
]

_AFTER_PROMPTS = [
    CoachPrompt(
        id="difficulty",
        label="How hard was that exercise? (1 easy – 5 maximal)",
        input_type="scale",
        scale_min=1,
        scale_max=5,
    ),
    CoachPrompt(
        id="notes",
        label="Anything to note (form, pain, preference)?",
        input_type="text",
        required=False,
    ),
]

_END_PROMPTS = [
    CoachPrompt(
        id="overall_feeling",
        label="Overall, how do you feel now? (1 poor – 5 great)",
        input_type="scale",
        scale_min=1,
        scale_max=5,
    ),
    CoachPrompt(
        id="fatigue_level",
        label="How fatigued are you? (1 fresh – 5 exhausted)",
        input_type="scale",
        scale_min=1,
        scale_max=5,
    ),
    CoachPrompt(
        id="comments",
        label="Any final comments for your coach?",
        input_type="text",
        required=False,
    ),
]

_PAIN_PATTERN = re.compile(
    r"\b(pain|hurt|hurts|sharp|injury|injured|ache|sore joint|knee|back pain)\b",
    re.IGNORECASE,
)


def _looks_like_pain(*texts: str | None) -> bool:
    blob = " ".join(t for t in texts if t)
    return bool(_PAIN_PATTERN.search(blob))


async def start_session_check_in(
    db: AsyncSession,
    profile: ProfileContext,
    *,
    program_name: str | None = None,
    upcoming_exercises: list[PlannedExerciseContext] | None = None,
) -> StartSessionResult:
    """Opening coach turn before the first exercise.

    What: short welcome + structured prompts (readiness / pain).
    Why: capture baseline feeling before work; UI/voice fill the prompts.
    How: optional RAG tip + Groq one short message; prompts are fixed schema.
    """
    upcoming = upcoming_exercises or []
    names = ", ".join(ex.exercise_name for ex in upcoming[:6]) or "your planned work"
    query = (
        f"warmup readiness {profile.limitations or ''} "
        f"{profile.primary_goal or ''} session start safety"
    )
    chunks = await retrieve_knowledge(db, query, limit=2)
    tips = "\n".join(c.content for c in chunks) if chunks else ""

    raw = await chat_completion(
        [
            {
                "role": "system",
                "content": (
                    "You are a concise in-workout fitness coach. "
                    "Return ONLY JSON: {\"message\": \"2-4 short sentences\"}. "
                    "Be practical and safe. Do not ask multiple questions in the message; "
                    "the app will show structured prompts separately."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"PROFILE\n{_profile_block(profile)}\n"
                    f"Program: {program_name or 'today\'s session'}\n"
                    f"Upcoming exercises: {names}\n"
                    f"Knowledge tips:\n{tips or '(none)'}\n"
                    "Write a brief start-of-session coach message."
                ),
            },
        ],
        temperature=0.3,
        max_tokens=250,
    )

    try:
        message = str(_extract_json(raw).get("message", "")).strip()
    except (json.JSONDecodeError, ValueError, AttributeError):
        message = raw.strip()
    if not message:
        message = (
            f"Let's get into {program_name or 'your session'}. "
            "Check how ready you feel, then we'll start with good form."
        )

    return StartSessionResult(message=message, prompts=_START_PROMPTS)


async def after_exercise_feedback(
    db: AsyncSession,
    profile: ProfileContext,
    payload: AfterExerciseInput,
    *,
    planned: PlannedExerciseContext | None = None,
) -> AfterExerciseResult:
    """Coach turn after one exercise is logged.

    What: short advice + structured SessionExerciseSnapshot for B to save.
    Why: mid-session signals drive safety cues and later adaptation.
    How: RAG on the exercise + Groq advice; normalize user scales into feedback.
    """
    planned_name = (planned.exercise_name if planned else None) or payload.exercise_name
    chunks = await retrieve_knowledge(
        db,
        f"{planned_name} form safety cues difficulty {payload.notes or ''} "
        f"{payload.user_message or ''} {profile.limitations or ''}",
        limit=3,
    )
    tips = "\n".join(f"- {c.content}" for c in chunks) if chunks else "(none)"

    raw = await chat_completion(
        [
            {
                "role": "system",
                "content": (
                    "You are a concise in-workout coach. Return ONLY JSON:\n"
                    '{"message":"2-4 short sentences of practical advice",'
                    '"safety_flag":false}\n'
                    "Set safety_flag true if the user reports sharp pain or should stop/"
                    "modify the movement. Keep advice actionable (form, rest, regression)."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"PROFILE\n{_profile_block(profile)}\n"
                    f"Exercise: {planned_name}\n"
                    f"Skipped: {payload.skipped}\n"
                    f"Sets completed: {payload.sets_completed}\n"
                    f"Reps: {payload.reps_completed}\n"
                    f"Weight_kg: {payload.weight_kg}\n"
                    f"Difficulty 1-5: {payload.difficulty}\n"
                    f"Notes: {payload.notes or 'none'}\n"
                    f"User message: {payload.user_message or 'none'}\n"
                    f"Knowledge:\n{tips}\n"
                ),
            },
        ],
        temperature=0.3,
        max_tokens=300,
    )

    safety = _looks_like_pain(payload.notes, payload.user_message)
    try:
        data = _extract_json(raw)
        message = str(data.get("message", "")).strip() or raw.strip()
        if "safety_flag" in data:
            safety = bool(data["safety_flag"]) or safety
    except (json.JSONDecodeError, ValueError):
        message = raw.strip() or "Nice work — keep form steady on the next set."

    notes = payload.notes
    if payload.user_message:
        notes = (
            f"{notes}; {payload.user_message}".strip("; ")
            if notes
            else payload.user_message
        )

    feedback = SessionExerciseSnapshot(
        exercise_name=planned_name,
        sets_completed=payload.sets_completed,
        reps_completed=payload.reps_completed,
        weight_kg=payload.weight_kg,
        difficulty=payload.difficulty,
        skipped=payload.skipped,
        notes=notes,
    )

    follow_ups: list[CoachPrompt] = []
    if safety:
        follow_ups.append(
            CoachPrompt(
                id="stop_or_modify",
                label="Do you want to stop this movement or switch to an easier variation?",
                input_type="text",
                required=False,
            )
        )

    return AfterExerciseResult(
        message=message,
        feedback=feedback,
        safety_flag=safety,
        prompts=follow_ups,
    )


async def end_session_coach(
    profile: ProfileContext,
    payload: EndSessionInput,
) -> EndSessionResult:
    """Closing coach turn; builds a SessionSnapshot ready to save + index.

    What: wrap-up message + structured session fields.
    Why: B saves the session then calls index_session_history for memory.
    How: Groq closing note; snapshot merges user scales/comments/exercises.
    """
    exercise_lines = []
    for ex in payload.exercises:
        flag = "SKIPPED" if ex.skipped else "done"
        exercise_lines.append(
            f"- {ex.exercise_name} [{flag}] difficulty={ex.difficulty} notes={ex.notes}"
        )

    raw = await chat_completion(
        [
            {
                "role": "system",
                "content": (
                    "You are a concise fitness coach ending a session. Return ONLY JSON:\n"
                    '{"message":"3-5 short sentences",'
                    '"comments":"optional cleaned summary note for the log or null"}\n'
                    "Acknowledge effort, mention recovery if fatigue is high, and note any "
                    "pain/skips briefly. No medical diagnosis."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"PROFILE\n{_profile_block(profile)}\n"
                    f"Feeling: {payload.overall_feeling}\n"
                    f"Fatigue: {payload.fatigue_level}\n"
                    f"Duration_min: {payload.duration_minutes}\n"
                    f"User comments: {payload.comments or 'none'}\n"
                    f"User message: {payload.user_message or 'none'}\n"
                    "Exercises:\n"
                    + ("\n".join(exercise_lines) if exercise_lines else "(none)")
                ),
            },
        ],
        temperature=0.3,
        max_tokens=350,
    )

    cleaned_comments = payload.comments
    try:
        data = _extract_json(raw)
        message = str(data.get("message", "")).strip() or raw.strip()
        if data.get("comments"):
            cleaned_comments = str(data["comments"]).strip()
    except (json.JSONDecodeError, ValueError):
        message = raw.strip() or "Session complete — recover well and note how you feel tomorrow."

    if payload.user_message:
        cleaned_comments = (
            f"{cleaned_comments}; {payload.user_message}".strip("; ")
            if cleaned_comments
            else payload.user_message
        )

    snapshot = SessionSnapshot(
        overall_feeling=payload.overall_feeling,
        fatigue_level=payload.fatigue_level,
        comments=cleaned_comments,
        duration_minutes=payload.duration_minutes,
        exercises=payload.exercises,
    )
    return EndSessionResult(message=message, snapshot=snapshot, prompts=[])


async def mid_session_coach(
    db: AsyncSession,
    profile: ProfileContext,
    payload: MidSessionInput,
) -> MidSessionResult:
    """Richer mid-workout dialogue turn (beyond fixed scales).

    What: answer a free-form user message during the session.
    Why: voice/typed questions like "should I skip this?" need a coach reply + action.
    How: RAG + Groq JSON with suggested_action for the UI to act on.
    """
    current = payload.current_exercise.exercise_name if payload.current_exercise else "unknown"
    upcoming = ", ".join(ex.exercise_name for ex in payload.upcoming_exercises[:5]) or "none"
    recent = []
    for ex in payload.recent_feedback[-3:]:
        recent.append(
            f"{ex.exercise_name} skipped={ex.skipped} difficulty={ex.difficulty} notes={ex.notes}"
        )
    chunks = await retrieve_knowledge(
        db,
        f"{payload.user_message} {current} {profile.limitations or ''} form safety fatigue",
        limit=3,
    )
    tips = "\n".join(c.content for c in chunks) if chunks else "(none)"
    safety_hint = _looks_like_pain(payload.user_message)

    raw = await chat_completion(
        [
            {
                "role": "system",
                "content": (
                    "You are an in-workout coach handling a mid-session question. "
                    "Return ONLY JSON:\n"
                    '{"message":"2-5 short sentences",'
                    '"safety_flag":false,'
                    '"suggested_action":"continue|regress_exercise|skip_exercise|rest|end_session"}\n'
                    "Be practical and safe. Prefer continue unless pain/exhaustion warrants change."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"PROFILE\n{_profile_block(profile)}\n"
                    f"Readiness 1-5: {payload.readiness}\n"
                    f"Current exercise: {current}\n"
                    f"Upcoming: {upcoming}\n"
                    f"Recent logged: {'; '.join(recent) if recent else 'none'}\n"
                    f"User says: {payload.user_message}\n"
                    f"Knowledge:\n{tips}\n"
                ),
            },
        ],
        temperature=0.3,
        max_tokens=350,
    )

    action = "continue"
    safety = safety_hint
    try:
        data = _extract_json(raw)
        message = str(data.get("message", "")).strip() or raw.strip()
        safety = bool(data.get("safety_flag", False)) or safety
        candidate = str(data.get("suggested_action", "continue")).strip()
        if candidate in {
            "continue",
            "regress_exercise",
            "skip_exercise",
            "rest",
            "end_session",
        }:
            action = candidate
    except (json.JSONDecodeError, ValueError):
        message = raw.strip() or "Keep going with solid form — tell me if anything hurts."

    prompts: list[CoachPrompt] = []
    if safety or action != "continue":
        prompts.append(
            CoachPrompt(
                id="confirm_action",
                label=f"Confirm coach suggestion ({action})? Yes/No or explain.",
                input_type="text",
                required=False,
            )
        )

    return MidSessionResult(
        message=message,
        safety_flag=safety,
        suggested_action=action,  # type: ignore[arg-type]
        prompts=prompts,
    )
